$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestTransfer < Base

    def setup
      setup_base

      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    def test_transfer_with_default_billing_policy

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)


      # Check active bundle
      active_bundle = get_active_bundle_by_key(bp.external_key, @options)
      assert_equal(active_bundle.account_id, @account.account_id)

      # Move clock  (BP after trial)
      kb_clock_add_days(30, nil, @options) # 31/08/2013
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Move clock  (BP after trial)
      kb_clock_add_days(1, nil, @options) # 01/09/2013

      new_account = create_account(@user, @options)

      # By default will trigger an EOT cancellation for billing , but immediate transfer
      new_bundle = transfer_bundle(new_account.account_id, bp.bundle_id, nil, nil, @user, @options)
      wait_for_expected_clause(1, new_account, @options, &@proc_account_invoices_nb)

      # Verify state of the old bundle (entitlement and billing cancelled date should be set to the transfer date)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(1, subscriptions.size)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-01", DEFAULT_KB_INIT_DATE, "2013-09-30")
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                               {:type => "START_BILLING", :date => "2013-08-01"},
                               {:type => "PHASE", :date => "2013-08-31"},
                               {:type => "STOP_ENTITLEMENT", :date => "2013-09-01"},
                               {:type => "STOP_BILLING", :date => "2013-09-30"}], bp.events)


      # Check active bundle (from its external_key as changed)
      active_bundle = get_active_bundle_by_key(bp.external_key, @options)
      assert_equal(active_bundle.account_id, new_account.account_id)
      assert_equal(active_bundle.bundle_id, new_bundle.bundle_id)

      # Verify state of the new bundle
      subscriptions = new_bundle.subscriptions
      assert_equal(1, subscriptions.size)
      bp = subscriptions[0]
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-09-01", nil, "2013-09-01", nil)
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-09-01"},
                               {:type => "START_BILLING", :date => "2013-09-01"},
                               ], bp.events)
    end

    def test_with_ao_and_immediate_billing_policy

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock  (BP still in trial)
      kb_clock_add_days(1, nil, @options) # 02/08/2013

      # Create Add-on 1
      ao1 = create_entitlement_ao(@account.account_id, bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-02", nil)

      # Check active bundle
      active_bundle = get_active_bundle_by_key(bp.external_key, @options)
      assert_equal(active_bundle.account_id, @account.account_id)

      # Move clock  (BP still in trial)
      kb_clock_add_days(3, nil, @options) # 05/08/2013

      new_account = create_account(@user, @options)
      new_bundle = transfer_bundle(new_account.account_id, bp.bundle_id, nil, 'IMMEDIATE', @user, @options)

      # Verify state of the old bundle (entitlement and billing cancelled date should be set to the transfer date)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(2, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-08-05", DEFAULT_KB_INIT_DATE, "2013-08-05")
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                               {:type => "START_BILLING", :date => "2013-08-01"},
                               {:type => "STOP_ENTITLEMENT", :date => "2013-08-05"},
                               {:type => "STOP_BILLING", :date => "2013-08-05"}], bp.events)
      # BUG Billing end date for ADD_ON during transfer is not set
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-02", "2013-08-05", "2013-08-02", "2013-08-05")
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-02"},
                                {:type => "START_BILLING", :date => "2013-08-02"},
                                {:type => "STOP_ENTITLEMENT", :date => "2013-08-05"},
                                {:type => "STOP_BILLING", :date => "2013-08-05"}], ao1.events)

      # Check active bundle (from its external_key as changed)
      active_bundle = get_active_bundle_by_key(bp.external_key, @options)
      assert_equal(active_bundle.account_id, new_account.account_id)
      assert_equal(active_bundle.bundle_id, new_bundle.bundle_id)

      # Verify state of the new bundle
      subscriptions = new_bundle.subscriptions
      assert_equal(2, subscriptions.size)
      bp = subscriptions.find { |s| s.product_category == 'BASE' }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-05", nil, "2013-08-05", nil)
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-05"},
                               {:type => "START_BILLING", :date => "2013-08-05"},
                               {:type => "PHASE", :date => "2013-08-31"}], bp.events)

      ao1 = subscriptions.find { |s| s.product_category == 'ADD_ON' }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil, "2013-08-05", nil)
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-05"},
                                {:type => "START_BILLING", :date => "2013-08-05"},
                                {:type => "PHASE", :date => "2013-09-01"}], ao1.events)

    end
  end
end

