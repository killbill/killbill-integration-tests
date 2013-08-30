module KillBillIntegrationTests
  module TestEntitlementUtil

    def create_entitlement_base(account_id, product_name, billing_period, price_list, user, options)
      create_entitlement('BASE', account_id, nil, product_name, billing_period, price_list, user, options)
    end

    def create_entitlement_ao(bundle_id, product_name, billing_period, price_list, user, options)
      create_entitlement('ADD_ON', nil, bundle_id, product_name, billing_period, price_list, user, options)
    end

    def get_entitlement(id, options)
      KillBillClient::Model::EntitlementNoEvents.find_by_id(id, options)
    end

    def get_subscription(id, options)
      KillBillClient::Model::SubscriptionNoEvents.find_by_id(id, options)
    end

    def get_subscriptions(bundle_id, options)
      KillBillClient::Model::SubscriptionNoEvents.find_by_bundle_id(bundle_id, options)
    end

    private

    def create_entitlement(category, account_id,  bundle_id, product_name, billing_period, price_list, user, options)

      result = KillBillClient::Model::EntitlementNoEvents.new
      result.account_id = account_id if category == 'BASE'
      result.external_key = Time.now.to_i.to_s if category == 'BASE'
      result.bundle_id = bundle_id if category == 'ADD_ON'
      result.product_name = product_name
      result.product_category = category
      result.billing_period = billing_period
      result.price_list = price_list

      result = result.create(user, nil, nil, options)
      assert_not_nil(result.subscription_id)

      result
    end

  end
end