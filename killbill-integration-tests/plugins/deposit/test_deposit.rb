# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../..', __dir__)
$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'plugin_base'

module KillBillIntegrationTests
  class TestDeposit < KillBillIntegrationTests::PluginBase
    PLUGIN_KEY = 'deposit'
    PLUGIN_NAME = 'killbill-deposit'
    # Default to latest
    PLUGIN_VERSION = nil

    PLUGIN_PROPS = [{ key: 'pluginArtifactId', value: 'deposit-plugin' },
                    { key: 'pluginGroupId', value: 'org.kill-bill.billing.plugin.java' },
                    { key: 'pluginType', value: 'java' }].freeze

    PLUGIN_CONFIGURATION = '!!org.killbill.billing.plugin.deposit.DepositConfiguration' + "\n" \
                           '  minAmounts:' + "\n" \
                           '    USD: 0.5'

    KILLBILL_DEPOSIT_PREFIX = '/plugins/killbill-deposit'

    def setup
      @user = 'Deposit test plugin'
      setup_plugin_base('2020-05-01', PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
      set_configuration(PLUGIN_NAME, PLUGIN_CONFIGURATION)
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY)
    end

    def test_healthcheck
      healthcheck = JSON.parse(KillBillClient::API.get("#{KILLBILL_DEPOSIT_PREFIX}/healthcheck", {}, @options).body)
      assert_equal(0, healthcheck.size, healthcheck)
    end
  end
end
