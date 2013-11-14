require 'checker_base'

module KillBillIntegrationTests
  module EntitlementChecker

    include CheckerBase

    def check_subscription(s, product_name, product_category, billing_period, price_list, start_date, cancelled_date, billing_start_date, billing_end_date)
      check_entitlement(s, product_name, product_category, billing_period, price_list, start_date, cancelled_date)
      check_with_nil(s.billing_start_date, billing_start_date)
      check_with_nil(s.billing_end_date, billing_end_date)
    end


    def check_entitlement(e, product_name, product_category, billing_period, price_list, start_date, cancelled_date)
      check_with_nil(e.product_name, product_name)
      check_with_nil(e.product_category, product_category)
      check_with_nil(e.billing_period, billing_period)
      check_with_nil(e.price_list, price_list)
      check_with_nil(e.start_date, start_date)
      check_with_nil(e.cancelled_date, cancelled_date)
    end

    def check_events(real, expected)
      assert_equal(real.size, expected.size)
      expected.each_with_index() do |e, i|
        assert_equal(real[i].event_type, e[:type])
        assert_equal(real[i].effective_date, e[:date])
      end
    end


  end
end
