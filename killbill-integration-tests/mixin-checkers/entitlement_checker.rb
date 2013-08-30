require 'checker_base'

module KillBillIntegrationTests
  module EntitlementChecker

    include CheckerBase

    def check_subscription(s, product_name, product_category, billing_period, price_list, cancelled_date, billing_end_date)
      check_entitlement(s, product_name, product_category, billing_period, price_list, cancelled_date)
      check_with_nil(s.billing_end_date, billing_end_date)
    end


    def check_entitlement(e, product_name, product_category, billing_period, price_list, cancelled_date)
      check_with_nil(e.product_name, product_name)
      check_with_nil(e.product_category, product_category)
      check_with_nil(e.billing_period, billing_period)
      check_with_nil(e.price_list, price_list)
      check_with_nil(e.cancelled_date, cancelled_date)
    end

  end
end
