require 'checker_base'

module KillBillIntegrationTests
  module EntitlementChecker

    include CheckerBase

    def check_subscription(s, product_name, product_category, billing_period, price_list, start_date, cancelled_date, billing_start_date, billing_end_date)
      check_entitlement(s, product_name, product_category, billing_period, price_list, start_date, cancelled_date)
      check_with_nil(billing_start_date, s.billing_start_date)
      check_with_nil(billing_end_date, s.billing_end_date)
    end


    def check_entitlement(e, product_name, product_category, billing_period, price_list, start_date, cancelled_date)
      check_with_nil(product_name, e.product_name)
      check_with_nil(product_category, e.product_category)
      check_with_nil(billing_period, e.billing_period)
      check_with_nil(price_list, e.price_list)
      check_with_nil(start_date, e.start_date)
      check_with_nil(cancelled_date, e.cancelled_date)
    end


    def check_events(expected, real)
      assert_equal(expected.size, real.size, real)
      expected.each_with_index() do |e, i|
        assert_equal(e[:type], real[i].event_type) if e.has_key?(:type)
        assert_equal(e[:date], real[i].effective_date) if e.has_key?(:date)
        assert_equal(e[:billing_period], real[i].billing_period) if e.has_key?(:billing_period)
        assert_equal(e[:product], real[i].product) if e.has_key?(:product)
        assert_equal(e[:plan], real[i].plan) if e.has_key?(:plan)
        assert_equal(e[:phase], real[i].phase) if e.has_key?(:phase)
        assert_equal(e[:price_list], real[i].price_list) if e.has_key?(:price_list)
        assert_equal(e[:is_blocked_billing], real[i].is_blocked_billing) if e.has_key?(:is_blocked_billing)
        assert_equal(e[:is_blocked_entitlement], real[i].is_blocked_entitlement) if e.has_key?(:is_blocked_entitlement)
        assert_equal(e[:service_name], real[i].service_name) if e.has_key?(:service_name)
        assert_equal(e[:service_state_name], real[i].service_state_name) if e.has_key?(:service_state_name)
      end
    end
  end
end
