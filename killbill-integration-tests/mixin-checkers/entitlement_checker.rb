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
        assert_equal(e[:type], real[i].event_type)
        assert_equal(e[:date], real[i].effective_date)
      end
    end


  end
end
