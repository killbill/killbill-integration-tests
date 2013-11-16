$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestTransfer < Base

    def setup
      @user = "EntitlementTransfer"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
    end

    def teardown
      teardown_base
    end

    def test_basic

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)


      # Check active bundle
      active_bundle = get_active_bundle_by_key(bp.external_key, @options)
      assert_equal(@account.account_id, active_bundle.account_id)

      # Move clock  (BP still in trial)
      kb_clock_add_days(4, nil, @options) # 05/08/2013

      new_account = create_account(@user, nil, @options)
      new_bundle = transfer(new_account.account_id, bp.bundle_id, nil, @user, @options)

      # Verify state of the old bundle (entitlement and billing cancelled date should be set to the transfer date)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(subscriptions.size, 1)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-08-05", DEFAULT_KB_INIT_DATE, "2013-08-05")
      check_events(bp.events, [{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                               {:type => "START_BILLING", :date => "2013-08-01"},
                               {:type => "STOP_ENTITLEMENT", :date => "2013-08-05"},
                               {:type => "STOP_BILLING", :date => "2013-08-05"}])


      # Check active bundle (from its external_key as changed)
      active_bundle = get_active_bundle_by_key(bp.external_key, @options)
      assert_equal(new_account.account_id, active_bundle.account_id)
      assert_equal(new_bundle.bundle_id, active_bundle.bundle_id)

      # Verify state of the new bundle
      subscriptions = new_bundle.subscriptions
      assert_equal(subscriptions.size, 1)
      bp = subscriptions[0]
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-05", nil, "2013-08-05", nil)
      check_events(bp.events, [{:type => "START_ENTITLEMENT", :date => "2013-08-05"},
                               {:type => "START_BILLING", :date => "2013-08-05"},
                               {:type => "PHASE", :date => "2013-08-31"}])

    end


    def test_with_ao

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock  (BP still in trial)
      kb_clock_add_days(1, nil, @options) # 02/08/2013

      # Create Add-on 1
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-02", nil)

      # Check active bundle
      active_bundle = get_active_bundle_by_key(bp.external_key, @options)
      assert_equal(@account.account_id, active_bundle.account_id)

      # Move clock  (BP still in trial)
      kb_clock_add_days(3, nil, @options) # 05/08/2013

      new_account = create_account(@user, nil, @options)
      new_bundle = transfer(new_account.account_id, bp.bundle_id, nil, @user, @options)

      # Verify state of the old bundle (entitlement and billing cancelled date should be set to the transfer date)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(subscriptions.size, 2)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-08-05", DEFAULT_KB_INIT_DATE, "2013-08-05")
      check_events(bp.events, [{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                               {:type => "START_BILLING", :date => "2013-08-01"},
                               {:type => "STOP_ENTITLEMENT", :date => "2013-08-05"},
                               {:type => "STOP_BILLING", :date => "2013-08-05"}])
      # BUG Billing end date for ADD_ON during transfer is not set
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-02", "2013-08-05", "2013-08-02", "2013-08-05")
      check_events(ao1.events, [{:type => "START_ENTITLEMENT", :date => "2013-08-02"},
                                {:type => "START_BILLING", :date => "2013-08-02"},
                                {:type => "STOP_ENTITLEMENT", :date => "2013-08-05"},
                                {:type => "STOP_BILLING", :date => "2013-08-05"}])

      # Check active bundle (from its external_key as changed)
      active_bundle = get_active_bundle_by_key(bp.external_key, @options)
      assert_equal(new_account.account_id, active_bundle.account_id)
      assert_equal(new_bundle.bundle_id, active_bundle.bundle_id)

      # Verify state of the new bundle
      subscriptions = new_bundle.subscriptions
      assert_equal(subscriptions.size, 2)
      bp = subscriptions.find { |s| s.product_category == 'BASE' }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-05", nil, "2013-08-05", nil)
      check_events(bp.events, [{:type => "START_ENTITLEMENT", :date => "2013-08-05"},
                               {:type => "START_BILLING", :date => "2013-08-05"},
                               {:type => "PHASE", :date => "2013-08-31"}])

      ao1 = subscriptions.find { |s| s.product_category == 'ADD_ON' }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil, "2013-08-05", nil)
      check_events(ao1.events, [{:type => "START_ENTITLEMENT", :date => "2013-08-05"},
                                {:type => "START_BILLING", :date => "2013-08-05"},
                                {:type => "PHASE", :date => "2013-09-01"}])

    end


  end
end

