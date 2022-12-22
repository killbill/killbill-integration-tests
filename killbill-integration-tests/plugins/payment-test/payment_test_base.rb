# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../..', __dir__)
$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'plugin_base'

module KillBillIntegrationTests
  class PaymentTestBase < KillBillIntegrationTests::PluginBase
    PLUGIN_KEY = 'payment-test'
    PLUGIN_NAME = 'killbill-payment-test'
    # Default to latest
    PLUGIN_VERSION = nil

    PLUGIN_PROPS = [{ key: 'pluginArtifactId', value: 'payment-test-plugin' },
                    { key: 'pluginGroupId', value: 'org.kill-bill.billing.plugin.java' },
                    { key: 'pluginType', value: 'java' }].freeze

    KILLBILL_PAYMENT_TEST_PREFIX = '/plugins/killbill-payment-test'

    def setup
      @user = 'Payment test plugin'
      @plugins_info = setup_plugin_base(DEFAULT_KB_INIT_CLOCK, PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
    end

    def teardown
      body = { 'CONFIGURE_ACTION': 'ACTION_CLEAR' }.to_json
      KillBillClient::API.post(KILLBILL_PAYMENT_TEST_PREFIX + '/configure', body, {}, @options)

      teardown_plugin_base(PLUGIN_KEY)
    end
  end
end
