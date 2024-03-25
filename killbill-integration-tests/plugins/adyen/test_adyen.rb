# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../..', __dir__)
$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'plugin_base'

module KillBillIntegrationTests
  class TestAdyen < KillBillIntegrationTests::PluginBase
    PLUGIN_KEY = 'adyen'
    PLUGIN_NAME = 'adyen-plugin'
    # Default to latest
    PLUGIN_VERSION = nil

    PLUGIN_PROPS = [{ key: 'pluginArtifactId', value: 'adyen-plugin' },
                    { key: 'pluginGroupId', value: 'org.kill-bill.billing.plugin.java' },
                    { key: 'pluginType', value: 'java' }].freeze

    KILLBILL_ADYEN_PREFIX = '/plugins/adyen-plugin'

    def setup
      @user = 'Adyen plugin'
      setup_plugin_base('2020-05-01', PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY, PLUGIN_VERSION)
    end

    def test_healthcheck
      healthcheck = JSON.parse(KillBillClient::API.get("#{KILLBILL_ADYEN_PREFIX}/healthcheck", {}, @options).body)
      assert_equal(1, healthcheck.size)
      assert_equal('Adyen OK', healthcheck['message'])
    end
  end
end
