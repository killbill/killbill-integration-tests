require 'logger'

require 'plugins_error_handling_base'
require 'proxy'

module KillBillIntegrationTests

  # This test expects the following cybersource.yml:
  #   :cybersource:
  #     - :account_id: default
  #       :proxy_address: 127.0.0.1
  #       :proxy_port: 2500
  #       :test: true
  class TestCybersource < PluginsErrorHandlingBase

    class << self
      def startup
        logger = Logger.new(STDOUT)
        logger.level = Logger::INFO

        # Setup the mock gateway
        @@proxy = Proxy.new(logger, PluginsErrorHandlingBase::PROXY_HOST, PluginsErrorHandlingBase::PROXY_PORT)
        @@proxy.start
      end

      def shutdown
        @@proxy.stop
      end
    end

    def setup
      @plugin = 'cybersource'
      @plugin_name = "killbill-#{@plugin}"

      setup_base
      setup_account_and_payment_method
    end

    def test_broken_connection
      # The call will go through to CyberSource but break on the way back
      @@proxy.uri_to_break = 'ics2wstest.ic3.com:443'
      @@proxy.min_data_chunk_nb_to_break = 7

      setup_plugin(build_config_with_on_demand_api)

      # Should it be SUCCESS? See https://github.com/killbill/killbill/issues/341
      transaction = trigger_purchase('UNKNOWN', 'End of file reached', 'EOFError')
    end

    private

    def build_config
      ":#{@plugin}:
  - :account_id: default
    :login: #{ENV['LOGIN']}
    :password: #{ENV['PASSWORD']}"
    end

    def build_config_with_on_demand_api
      "#{build_config}
  - :account_id: on_demand
    :merchantID: #{ENV['MERCHANT_ID']}
    :username: #{ENV['OD_USERNAME']}
    :password: #{ENV['OD_PASSWORD']}"
    end
  end
end
