module KillBillIntegrationTests
  module EntitlementHelper

    def transfer_bundle(new_account_id, bundle_id, requested_date, billing_policy, user, options)
      bundle = KillBillClient::Model::Bundle.new
      bundle.account_id = new_account_id
      bundle.bundle_id = bundle_id
      res = bundle.transfer(requested_date, billing_policy, user, nil, nil, options)
      res
    end

    def pause_bundle(bundle_id, requested_date, user, options)
      bundle = KillBillClient::Model::Bundle.new
      bundle.bundle_id = bundle_id
      bundle.pause(requested_date, user, nil, nil, options)
    end

    def resume_bundle(bundle_id, requested_date, user, options)
      bundle = KillBillClient::Model::Bundle.new
      bundle.bundle_id = bundle_id
      bundle.resume(requested_date, user, nil, nil, options)
    end

    def create_entitlement_base(account_id, product_name, billing_period, price_list, user, options)
      create_entitlement('BASE', account_id, nil, product_name, billing_period, price_list, user, options)
    end

    def create_entitlement_ao(bundle_id, product_name, billing_period, price_list, user, options)
      create_entitlement('ADD_ON', nil, bundle_id, product_name, billing_period, price_list, user, options)
    end

    def get_subscription(id, options)
      KillBillClient::Model::Subscription.find_by_id(id, options)
    end

    def get_subscription(id, options)
      KillBillClient::Model::Subscription.find_by_id(id, options)
    end

    def get_bundle(bundle_id, options)
      KillBillClient::Model::Bundle.find_by_id(bundle_id, options)
    end

    def get_active_bundle_by_key(external_key, options)
      KillBillClient::Model::Bundle.find_by_external_key(external_key, options)
    end


    def get_subscriptions(bundle_id, options)
      (KillBillClient::Model::Bundle.find_by_id(bundle_id, options).subscriptions || [])
    end

    private

    def create_entitlement(category, account_id,  bundle_id, product_name, billing_period, price_list, user, options)

      result = KillBillClient::Model::Subscription.new
      result.account_id = account_id if category == 'BASE'
      result.external_key = "#{account_id}-" + Time.now.to_i.to_s if category == 'BASE'
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
