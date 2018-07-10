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

    def set_bundle_blocking_state(bundle_id, state_name, service, block_change, block_entitlement, block_billing, requested_date, user, options)
      bundle = KillBillClient::Model::Bundle.new
      bundle.bundle_id = bundle_id
      bundle.set_blocking_state(state_name, service, block_change, block_entitlement, block_billing, requested_date, user, nil, nil, options)
    end

    def set_subscription_blocking_state(subscription_id, state_name, service, block_change, block_entitlement, block_billing, requested_date, user, options)
      sub = KillBillClient::Model::Subscription.new
      sub.subscription_id = subscription_id
      sub.set_blocking_state(state_name, service, block_change, block_entitlement, block_billing, requested_date, user, nil, nil, options)
    end

    def create_entitlement_from_plan(account_id, external_key, plan_name, user, options)
      result = KillBillClient::Model::Subscription.new
      result.account_id = account_id
      result.external_key = external_key
      result.plan_name = plan_name
      result = result.create(user, nil, nil, nil, nil, options)
      assert_not_nil(result.subscription_id)

      result
    end

    def create_entitlement_base_with_overrides(account_id, product_name, billing_period, price_list, overrides, user, options)
      create_entitlement('BASE', account_id, nil, product_name, billing_period, price_list, nil, overrides, nil, user, options)
    end

    def create_entitlement_base_with_date(account_id, product_name, billing_period, price_list, requested_date, user, options)
      create_entitlement('BASE', account_id, nil, product_name, billing_period, price_list, nil, nil, requested_date, user, options)
    end


    def create_entitlement_base(account_id, product_name, billing_period, price_list, user, options)
      create_entitlement('BASE', account_id, nil, product_name, billing_period, price_list, nil, nil, nil, user, options)
    end

    def create_entitlement_base_skip_phase(account_id, product_name, billing_period, price_list, phase_type, user, options)
      create_entitlement('BASE', account_id, nil, product_name, billing_period, price_list, phase_type, nil, nil, user, options)
    end

    def create_entitlement_ao_with_overrides(account_id, bundle_id, product_name, billing_period, price_list, overrides, user, options)
      create_entitlement('ADD_ON', account_id, bundle_id, product_name, billing_period, price_list, nil, overrides, nil, user, options)
    end

    def create_entitlement_ao(account_id, bundle_id, product_name, billing_period, price_list, user, options)
      create_entitlement('ADD_ON', account_id, bundle_id, product_name, billing_period, price_list, nil, nil, nil, user, options)
    end

    def create_entitlement_ao_skip_phase(account_id, bundle_id, product_name, billing_period, price_list, phase_type, user, options)
      create_entitlement('ADD_ON', account_id, bundle_id, product_name, billing_period, price_list, phase_type, nil, nil, user, options)
    end

    def get_subscription(id, options)
      KillBillClient::Model::Subscription.find_by_id(id, options)
    end

    def get_bundle(bundle_id, options)
      KillBillClient::Model::Bundle.find_by_id(bundle_id, options)
    end

    def get_active_bundle_by_key(external_key, options)
      KillBillClient::Model::Bundle.find_by_external_key(external_key, false, options)
    end


    def get_subscriptions(bundle_id, options)
      (KillBillClient::Model::Bundle.find_by_id(bundle_id, options).subscriptions || [])
    end

    private


    def create_entitlement(category, account_id,  bundle_id, product_name, billing_period, price_list, phase_type, overrides, requested_date, user, options)

      result = KillBillClient::Model::Subscription.new
      result.account_id = account_id
      result.external_key = "#{account_id}-" + rand(1000000).to_s if category == 'BASE'
      result.bundle_id = bundle_id if category == 'ADD_ON'
      result.product_name = product_name
      result.product_category = category
      result.billing_period = billing_period
      result.price_list = price_list
      result.price_overrides = overrides unless overrides.nil?
      result.phase_type = phase_type

      result = result.create(user, nil, nil, requested_date, nil, options)
      assert_not_nil(result.subscription_id)

      result
    end

  end
end
