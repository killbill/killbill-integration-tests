# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../..', __dir__)
$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'plugin_base'

module KillBillIntegrationTests
  class TestQualpay < KillBillIntegrationTests::PluginBase
    PLUGIN_KEY = 'qualpay'
    PLUGIN_NAME = 'killbill-qualpay'
    # Default to latest
    PLUGIN_VERSION = nil

    PLUGIN_PROPS = [{ key: 'pluginArtifactId', value: 'qualpay-plugin' },
                    { key: 'pluginGroupId', value: 'org.kill-bill.billing.plugin.java' },
                    { key: 'pluginType', value: 'java' }].freeze

    PLUGIN_CONFIGURATION = "org.killbill.billing.plugin.qualpay.apiKey=#{ENV['QUALPAY_API_KEY']}" + "\n" \
                           "org.killbill.billing.plugin.qualpay.merchantId=#{ENV['QUALPAY_MERCHANT_ID']}"

    KILLBILL_QUALPAY_PREFIX = '/plugins/killbill-qualpay'

    def setup
      @user = 'Qualpay test plugin'
      setup_plugin_base('2020-05-01', PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
      set_configuration(PLUGIN_NAME, PLUGIN_CONFIGURATION)
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY, PLUGIN_VERSION)
    end

    def test_healthcheck
      healthcheck = if ENV['QUALPAY_API_KEY'].nil?
                      JSON.parse(KillBillClient::API.get("#{KILLBILL_QUALPAY_PREFIX}/healthcheck", {}, {}).body)
                    else
                      # This will hit Qualpay
                      JSON.parse(KillBillClient::API.get("#{KILLBILL_QUALPAY_PREFIX}/healthcheck", {}, @options).body)
                    end
      assert_equal(1, healthcheck.size)
      assert_equal('Qualpay OK', healthcheck['message'])
    end
  end
end
