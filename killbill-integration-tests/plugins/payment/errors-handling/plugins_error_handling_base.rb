require 'toxiproxy'

require 'test_base'

module KillBillIntegrationTests

  class PluginsErrorHandlingBase < Base

    # A few tests require Toxiproxy, see https://github.com/Shopify/toxiproxy
    PROXY_NAME = 'gateway'
    PROXY_HOST = 'localhost'
    PROXY_PORT= 2500

    def teardown
      teardown_base
    end

    protected

    # Note: by default, the mock gateway returns 200 but with a buggy body, which is interpreted as a failed payment
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
      KillBillClient::Model::Tenant.upload_tenant_plugin_config(@plugin_name, config, @user, @reason, @comment, @options)
      sleep 1 # Wait for invalidation...
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
      add_payment_method(@account.account_id, @plugin_name, true, plugin_info, @user, pm_options)
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

    def build_proxy_config
      ":#{@plugin}:
  :test_url: http://#{PROXY_HOST}:#{PROXY_PORT}"
    end

    def build_default_config
      ":#{@plugin}:
  :test: true"
    end
  end
end
