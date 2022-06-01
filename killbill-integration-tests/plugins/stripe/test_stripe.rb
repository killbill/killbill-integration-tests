# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('.', __dir__)

require 'stripe_base'

module KillBillIntegrationTests
  class TestStripe < KillBillIntegrationTests::StripeBase
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
