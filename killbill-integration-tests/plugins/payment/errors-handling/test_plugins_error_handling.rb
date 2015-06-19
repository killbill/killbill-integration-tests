$LOAD_PATH.unshift File.expand_path('../../../../', __FILE__)

require 'logger'
require 'toxiproxy'

require 'test_base'
require 'gateway'

module KillBillIntegrationTests

  class TestPluginsErrorHandling < Base

    # A few tests require Toxiproxy, see https://github.com/Shopify/toxiproxy
    PROXY_NAME = 'gateway'
    PROXY_HOST = 'localhost'
    PROXY_PORT= 2500

    class << self
      def startup
        @@plugin = 'cybersource'
        @@plugin_name = "killbill-#{@@plugin}"

        logger = Logger.new(STDOUT)
        logger.level = Logger::INFO

        # Setup the mock gateway
        @@gateway = Gateway.new(logger)
        @@gateway.start

        # Setup Toxiproxy
        Toxiproxy.populate([
                               {
                                   :name => PROXY_NAME,
                                   :listen => "#{PROXY_HOST}:#{PROXY_PORT}",
                                   :upstream => "#{@@gateway.host}:#{@@gateway.port}"
                               }
                           ])
      end

      def shutdown
        @@gateway.stop
        Toxiproxy[PROXY_NAME.to_sym].destroy
      end
    end

    def setup
      setup_base
      @@gateway.reset
      setup_account_and_payment_method
    end

    def teardown
      teardown_base
    end

    #
    # Tests with mis-behaving gateway
    #

    def test_direct_purchase_with_broken_pipe
      setup_plugin(build_gateway_config)

      @@gateway.trigger_broken_pipe = true

      transaction = trigger_purchase('UNKNOWN', 'Broken pipe - Broken pipe', 'Errno::EPIPE')

      @@gateway.reset

      # Check the recovery behavior for the Janitor (no-op by default)
      check_purchase(transaction.payment_id, 'UNKNOWN', 'Broken pipe - Broken pipe', 'Errno::EPIPE')
    end

    def test_direct_purchase_with_eof_error
      setup_plugin(build_gateway_config)

      @@gateway.trigger_eof_error = true

      transaction = trigger_purchase('UNKNOWN', 'End of file reached', 'EOFError')

      @@gateway.reset

      # Check the recovery behavior for the Janitor (no-op by default)
      check_purchase(transaction.payment_id, 'UNKNOWN', 'End of file reached', 'EOFError')
    end

    #
    # Tests with proxy and network issues
    #

    def test_proxy_down
      setup_plugin(build_proxy_config)

      transaction = nil
      toxiproxy.down do
        transaction = trigger_purchase('PLUGIN_FAILURE', 'Connection refused - Connection refused', 'Errno::ECONNREFUSED')
      end

      # Check the recovery behavior for the Janitor (no-op by default)
      check_purchase(transaction.payment_id, 'PLUGIN_FAILURE', 'Connection refused - Connection refused', 'Errno::ECONNREFUSED')
    end

    def test_proxy_high_latency
      setup_plugin(build_proxy_config)

      transaction = nil
      toxiproxy.upstream(:latency, :latency => 1500).downstream(:latency, :latency => 3000).apply do
        transaction = trigger_purchase
      end

      # Check the recovery behavior for the Janitor (no-op by default)
      check_purchase(transaction.payment_id)
    end

    def test_proxy_slow_close
      setup_plugin(build_proxy_config)

      transaction = nil
      toxiproxy.upstream(:slow_close, :delay => 1000).downstream(:slow_close, :delay => 2000).apply do
        transaction = trigger_purchase
      end

      # Check the recovery behavior for the Janitor (no-op by default)
      check_purchase(transaction.payment_id)
    end

    def test_proxy_timeout
      setup_plugin(build_proxy_config)

      transaction = nil
      toxiproxy.upstream(:timeout, :timeout => 2000).downstream(:latency, :timeout => 5000).apply do
        transaction = trigger_purchase('UNKNOWN', 'End of file reached', 'EOFError')
      end

      # Check the recovery behavior for the Janitor (no-op by default)
      check_purchase(transaction.payment_id, 'UNKNOWN', 'End of file reached', 'EOFError')
    end

    private

    # Note: by default, the gateway returns 200 but with a buggy body, which is interpreted as a failed payment
    def trigger_purchase(status = 'PAYMENT_FAILURE', gateway_error = nil, gateway_error_code = nil)
      payment_key = Time.now.to_i.to_s
      transaction = create_purchase(@account.account_id, payment_key, payment_key, 10, @account.currency, @user, @options)

      assert_equal(status, transaction.status)
      assert_equal(gateway_error, transaction.gateway_error_msg)
      assert_equal(gateway_error_code, transaction.gateway_error_code)
      transaction
    end

    def check_purchase(payment_id, status = 'PAYMENT_FAILURE', gateway_error = nil, gateway_error_code = nil)
      # TODO Implement this in the client library
      payment = KillBillClient::Model::Payment.get("#{KillBillClient::Model::Payment::KILLBILL_API_PAYMENTS_PREFIX}/#{payment_id}",
                                                   {:withPluginInfo => true},
                                                   @options)
      assert_equal(1, payment.transactions.size)
      transaction = payment.transactions.first

      assert_equal(status, transaction.status)
      assert_equal(gateway_error, transaction.gateway_error_msg)
      assert_equal(gateway_error_code, transaction.gateway_error_code)
      transaction
    end

    def setup_plugin(config = build_default_config)
      # Configure the plugin to go to our gateway
      KillBillClient::Model::Tenant.upload_tenant_plugin_config(@@plugin_name, config, @user, @reason, @comment, @options)
      sleep 1 # Wait for invalidation...
    end

    def build_gateway_config
      ":#{@@plugin}:
  :test_url: http://#{@@gateway.host}:#{@@gateway.port}"
    end

    def build_proxy_config
      ":#{@@plugin}:
  :test_url: http://#{PROXY_HOST}:#{PROXY_PORT}"
    end

    def build_default_config
      ":#{@@plugin}:
  :test: true"
    end

    def setup_account_and_payment_method
      @account = create_account(@user, @options)
      setup_plugin # Required to add the payment method
      setup_payment_method
    end

    def setup_payment_method(plugin_info = build_default_pm_details)
      skip_gw = KillBillClient::Model::PluginPropertyAttributes.new
      skip_gw.key = 'skip_gw'
      skip_gw.value = 'true'

      pm_options = @options.clone
      pm_options[:pluginProperty] = [skip_gw]
      add_payment_method(@account.account_id, @@plugin_name, true, plugin_info, @user, pm_options)
    end

    def build_default_pm_details
      {
          'email' => 'tom@killbill.io',
          'description' => Time.now.to_i.to_s,
          'ccFirstName' => 'Tom',
          'ccLastName' => 'Mot',
          'address1' => '5th street',
          'city' => 'San Francisco',
          'zip' => '94111',
          'state' => 'CA',
          'country' => 'US',
          'ccNumber' => '4242424242424242',
          'ccExpirationYear' => '2020',
          'ccExpirationMonth' => '10'
      }
    end

    def toxiproxy
      Toxiproxy[PROXY_NAME.to_sym]
    end
  end
end
