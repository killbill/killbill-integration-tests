$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class EntitlementAddOn < Base

    def setup
      @user = "EntitlementAddOn"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = setup_create_account(@user, default_time_zone, @options)
    end

    def teardown
      teardown_base
    end

    def test_with_ao

      bp = setup_create_bp(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Create Add-on
      ao_entitlement = KillBillClient::Model::EntitlementNoEvents.new
      ao_entitlement.bundle_id = bp.bundle_id
      ao_entitlement.product_name = 'RemoteControl'
      ao_entitlement.product_category = 'ADD_ON'
      ao_entitlement.billing_period = 'MONTHLY'
      ao_entitlement.price_list = 'DEFAULT'

      # Create ADD_ON
      ao_entitlement = ao_entitlement.create(@user, nil, nil, @options)
      assert_not_nil(ao_entitlement.subscription_id)
      assert_equal(ao_entitlement.product_name, 'RemoteControl')
      assert_equal(ao_entitlement.product_category, 'ADD_ON')
      assert_equal(ao_entitlement.billing_period, 'MONTHLY')
      assert_equal(ao_entitlement.price_list, 'DEFAULT')
      assert_nil(ao_entitlement.cancelled_date)

      subscriptions = KillBillClient::Model::SubscriptionNoEvents.find_by_bundle_id(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(subscriptions.size, 2)

      bps = subscriptions.reject { |s| s.product_category == 'ADD_ON' }
      assert_not_nil(bps)
      assert_equal(bps.size, 1)
      assert_equal(bps[0].subscription_id , bp.subscription_id)

      aos = subscriptions.reject { |s| s.product_category == 'BASE' }
      assert_not_nil(aos)
      assert_equal(aos.size, 1)
      assert_equal(aos[0].subscription_id , ao_entitlement.subscription_id)
    end
  end
end

