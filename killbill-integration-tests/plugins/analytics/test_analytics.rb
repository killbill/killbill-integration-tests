# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../..', __dir__)
$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'plugin_base'

module KillBillIntegrationTests
  class TestAnalytics < KillBillIntegrationTests::PluginBase
    PLUGIN_KEY = 'analytics'
    PLUGIN_NAME = 'killbill-analytics'
    # Default to latest
    PLUGIN_VERSION = nil

    PLUGIN_PROPS = [{ key: 'pluginArtifactId', value: 'analytics-plugin' },
                    { key: 'pluginGroupId', value: 'org.kill-bill.billing.plugin.java' },
                    { key: 'pluginType', value: 'java' }].freeze

    PLUGIN_CONFIGURATION = '!!org.killbill.billing.plugin.analytics.api.core.AnalyticsConfiguration' + "\n" \
                           '  refreshDelaySeconds: 0' + "\n" \
                           '  lockAttemptRetries: 100'

    KILLBILL_ANALYTICS_PREFIX = '/plugins/killbill-analytics'

    def setup
      @user = 'Analytics test plugin'
      setup_plugin_base('2020-05-01', PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
      set_configuration(PLUGIN_NAME, PLUGIN_CONFIGURATION)
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY)
    end

    def test_healthcheck
      # Put in rotation
      KillBillClient::API.put("#{KILLBILL_ANALYTICS_PREFIX}/healthcheck", nil, {}, @options)

      healthcheck = JSON.parse(KillBillClient::API.get("#{KILLBILL_ANALYTICS_PREFIX}/healthcheck", {}, @options).body)
      assert_equal(2, healthcheck.size)
      assert_true(healthcheck['AnalyticsListener'])
      assert_true(healthcheck['JobsScheduler'])
    end
  end
end
