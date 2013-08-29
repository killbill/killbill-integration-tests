$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class EntitlementChangePlanTest < Base

    def setup
      @user = "EntitlementChangePlanTest"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = setup_create_account(@user, default_time_zone, @options)
    end

    def teardown
      teardown_base
    end

    def test_change_default

      bp = setup_create_bp(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Change plan
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, nil, nil, false, @options)
      assert_equal(bp.product_name, 'Super')
      assert_equal(bp.product_category, 'BASE')
      assert_equal(bp.billing_period, 'MONTHLY')
      assert_equal(bp.price_list, 'DEFAULT')
      assert_nil(bp.cancelled_date)

      changed_bp = KillBillClient::Model::SubscriptionNoEvents.find_by_id(bp.subscription_id, @options)
      assert_not_nil(changed_bp)
      assert_nil(changed_bp.cancelled_date)
      assert_nil(changed_bp.billing_end_date)
    end

  end
end
