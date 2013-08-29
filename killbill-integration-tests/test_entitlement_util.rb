module KillBillIntegrationTests
  module TestEntitlementUtil

    def setup_create_bp(account_id, product_name, billing_period, price_list, user, options)
      # Create BP
      base_entitlement = KillBillClient::Model::EntitlementNoEvents.new
      base_entitlement.account_id = account_id
      base_entitlement.external_key = Time.now.to_i.to_s
      base_entitlement.product_name = product_name
      base_entitlement.product_category = 'BASE'
      base_entitlement.billing_period = billing_period
      base_entitlement.price_list = price_list

      base_entitlement = base_entitlement.create(user, nil, nil, options)
      assert_not_nil(base_entitlement.subscription_id)
      assert_equal(base_entitlement.product_name, product_name)
      assert_equal(base_entitlement.product_category, 'BASE')
      assert_equal(base_entitlement.billing_period, billing_period)
      assert_equal(base_entitlement.price_list, price_list)
      assert_nil(base_entitlement.cancelled_date)

      base_entitlement
    end

  end
end