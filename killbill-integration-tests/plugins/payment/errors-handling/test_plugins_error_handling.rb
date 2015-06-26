$LOAD_PATH.unshift File.expand_path('../../../../', __FILE__)

require 'logger'
require 'toxiproxy'

require 'plugins_error_handling_base'
require 'gateway'

module KillBillIntegrationTests

  class TestPluginsErrorHandling < PluginsErrorHandlingBase

    class << self
      def startup
        logger = Logger.new(STDOUT)
        logger.level = Logger::INFO

        # Setup the mock gateway
        @@gateway = Gateway.new(logger)
        @@gateway.start

        # Setup Toxiproxy
        Toxiproxy.populate([
                               {
                                   :name => PluginsErrorHandlingBase::PROXY_NAME,
                                   :listen => "#{PluginsErrorHandlingBase::PROXY_HOST}:#{PluginsErrorHandlingBase::PROXY_PORT}",
                                   :upstream => "#{@@gateway.host}:#{@@gateway.port}"
                               }
                           ])
      end

      def shutdown
        @@gateway.stop
        Toxiproxy[PluginsErrorHandlingBase::PROXY_NAME.to_sym].destroy
      end
    end

    def setup
      @plugin = 'cybersource'
      @plugin_name = "killbill-#{@plugin}"

      setup_base
      @@gateway.reset
      setup_account_and_payment_method
    end

    #
    # Tests with mis-behaving gateway
    #

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

    def build_gateway_config
      ":#{@plugin}:
  :test_url: http://#{@@gateway.host}:#{@@gateway.port}"
    end
  end
end
