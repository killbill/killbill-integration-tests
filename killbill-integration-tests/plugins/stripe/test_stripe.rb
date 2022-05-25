# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../..', __dir__)
$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'plugin_base'

module KillBillIntegrationTests
  class TestStripe < KillBillIntegrationTests::PluginBase
    PLUGIN_KEY = 'stripe'
    PLUGIN_NAME = 'killbill-stripe'
    # Default to latest
    PLUGIN_VERSION = nil

    PLUGIN_PROPS = [{ key: 'pluginArtifactId', value: 'stripe-plugin' },
                    { key: 'pluginGroupId', value: 'org.kill-bill.billing.plugin.java' },
                    { key: 'pluginType', value: 'java' }].freeze

    PLUGIN_CONFIGURATION = "org.killbill.billing.plugin.stripe.apiKey=#{ENV['STRIPE_API_KEY']}" + "\n" \
                           "org.killbill.billing.plugin.stripe.publicKey=#{ENV['STRIPE_PUBLIC_KEY']}"

    KILLBILL_STRIPE_PREFIX = '/plugins/killbill-stripe'

    def setup
      @user = 'Stripe test plugin'
      setup_plugin_base('2020-05-01', PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
      set_configuration(PLUGIN_NAME, PLUGIN_CONFIGURATION)
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY)
    end

    def test_healthcheck
      healthcheck = if ENV['STRIPE_API_KEY'].nil?
                      JSON.parse(KillBillClient::API.get("#{KILLBILL_STRIPE_PREFIX}/healthcheck", {}, {}).body)
                    else
                      # This will hit Stripe
                      JSON.parse(KillBillClient::API.get("#{KILLBILL_STRIPE_PREFIX}/healthcheck", {}, @options).body)
                    end
      assert_equal(1, healthcheck.size)
      assert_equal('Stripe OK', healthcheck['message'])
    end
  end
end
