# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../..', __dir__)
$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'plugin_base'

module KillBillIntegrationTests
  class TestGocardless < KillBillIntegrationTests::PluginBase
    PLUGIN_KEY = 'gocardless'
    PLUGIN_NAME = 'killbill-gocardless'
    # Default to latest
    PLUGIN_VERSION = nil

    PLUGIN_PROPS = [{ key: 'pluginArtifactId', value: 'gocardless-plugin' },
                    { key: 'pluginGroupId', value: 'org.kill-bill.billing.plugin.java' },
                    { key: 'pluginType', value: 'java' }].freeze

    PLUGIN_CONFIGURATION = "org.killbill.billing.plugin.gocardless.gocardlesstoken=#{ENV['GOCARDLESS_ACCESS_TOKEN_KEY']}" + "\n" \
                           "org.killbill.billing.plugin.gocardless.environment=#{ENV['GOCARDLESS_ENVIRONMENT_KEY']}"

    KILLBILL_GOCARDLESS_PREFIX = '/plugins/killbill-gocardless'

    def setup
      @user = 'Gocardless plugin'
      setup_plugin_base('2020-05-01', PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
      set_configuration(PLUGIN_NAME, PLUGIN_CONFIGURATION)
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY)
    end

    def test_healthcheck
      healthcheck = if ENV['GOCARDLESS_ACCESS_TOKEN_KEY'].nil?
                      JSON.parse(KillBillClient::API.get("#{KILLBILL_GOCARDLESS_PREFIX}/healthcheck", {}, {}).body)
                    else
                      # This will hit Gocardless
                      JSON.parse(KillBillClient::API.get("#{KILLBILL_GOCARDLESS_PREFIX}/healthcheck", {}, @options).body)
                    end
      assert_equal(1, healthcheck.size)
      assert_equal('Gocardless OK', healthcheck['message'])
    end
  end
end
