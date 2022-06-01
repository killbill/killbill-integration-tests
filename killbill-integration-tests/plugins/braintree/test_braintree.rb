# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../..', __dir__)
$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'plugin_base'

module KillBillIntegrationTests
  class TestBraintree < KillBillIntegrationTests::PluginBase
    PLUGIN_KEY = 'braintree'
    PLUGIN_NAME = 'killbill-braintree'
    # Default to latest
    PLUGIN_VERSION = nil

    PLUGIN_PROPS = [{ key: 'pluginArtifactId', value: 'braintree-plugin' },
                    { key: 'pluginGroupId', value: 'org.kill-bill.billing.plugin.java' },
                    { key: 'pluginType', value: 'java' }].freeze

    PLUGIN_CONFIGURATION = 'org.killbill.billing.plugin.braintree.btEnvironment=sandbox' + "\n" \
                           "org.killbill.billing.plugin.braintree.btMerchantId=#{ENV['BRAINTREE_MERCHANT_ID']}" + "\n" \
                           "org.killbill.billing.plugin.braintree.btPublicKey=#{ENV['BRAINTREE_PUBLIC_KEY']}" + "\n" \
                           "org.killbill.billing.plugin.braintree.btPrivateKey=#{ENV['BRAINTREE_PRIVATE_KEY']}"

    KILLBILL_BRAINTREE_PREFIX = '/plugins/killbill-braintree'

    def setup
      @user = 'Braintree test plugin'
      setup_plugin_base('2020-05-01', PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
      set_configuration(PLUGIN_NAME, PLUGIN_CONFIGURATION)
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY)
    end

    def test_healthcheck
      healthcheck = if ENV['BRAINTREE_MERCHANT_ID'].nil?
                      JSON.parse(KillBillClient::API.get("#{KILLBILL_BRAINTREE_PREFIX}/healthcheck", {}, {}).body)
                    else
                      # This will hit Braintree
                      JSON.parse(KillBillClient::API.get("#{KILLBILL_BRAINTREE_PREFIX}/healthcheck", {}, @options).body)
                    end
      assert_equal(1, healthcheck.size)
      assert_equal('Braintree OK', healthcheck['message'])
    end
  end
end
