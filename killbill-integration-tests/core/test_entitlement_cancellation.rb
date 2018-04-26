$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestEntitlementCancellation < Base

    def setup
      setup_base
      load_default_catalog
      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    # Cancellation with with explicit no arguments
    def test_bp_cancel_default_no_ctd
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Cancel BP  in trial with no arguments
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      canceled_bp = get_subscription(bp.subscription_id, @options)
      check_subscription(canceled_bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, DEFAULT_KB_INIT_DATE, DEFAULT_KB_INIT_DATE, DEFAULT_KB_INIT_DATE)

      bp_subscriptions = get_subscriptions(bp.bundle_id, @options)
      bp = bp_subscriptions.find { |s| s.subscription_id == bp.subscription_id }

      events = [{:type                    => 'START_ENTITLEMENT',
                 :date                   => DEFAULT_KB_INIT_DATE,
                 :billing_period         => 'MONTHLY',
                 :product                => 'Sports',
                 :plan                   => 'sports-monthly',
                 :phase                  => 'sports-monthly-trial',
                 :price_list             => 'DEFAULT',
                 :service_name           => 'entitlement-service',
                 :service_state_name     => 'ENT_STARTED'},
                {:type                   => 'START_BILLING',
                 :date                   => DEFAULT_KB_INIT_DATE,
                 :billing_period         => 'MONTHLY',
                 :product                => 'Sports',
                 :plan                   => 'sports-monthly',
                 :phase                  => 'sports-monthly-trial',
                 :price_list             => 'DEFAULT',
                 :service_name           => 'billing-service',
                 :service_state_name     => 'START_BILLING'},
                {:type                   => 'STOP_ENTITLEMENT',
                 :date                   => DEFAULT_KB_INIT_DATE,
                 :service_name           => 'entitlement-service',
                 :service_state_name     => 'ENT_CANCELLED'},
                {:type                   => 'STOP_BILLING',
                 :date                   => DEFAULT_KB_INIT_DATE,
                 :service_name           => 'billing-service',
                 :service_state_name     => 'STOP_BILLING'}]

      check_events(events, bp.events)

    end

    # Cancellation with with explicit no arguments
    def test_bp_cancel_default_with_ctd
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock after the trial to have a CTD
      kb_clock_add_days(31, nil, @options)

      # Cancel BP  in trial with no arguments
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      canceled_bp = get_subscription(bp.subscription_id, @options)
      check_subscription(canceled_bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-01", DEFAULT_KB_INIT_DATE, "2013-09-30")

      bp_subscriptions = get_subscriptions(bp.bundle_id, @options)
      bp = bp_subscriptions.find { |s| s.subscription_id == bp.subscription_id }

      events = [{:type                    => 'START_ENTITLEMENT',
                 :date                   => DEFAULT_KB_INIT_DATE,
                 :billing_period         => 'MONTHLY',
                 :product                => 'Sports',
                 :plan                   => 'sports-monthly',
                 :phase                  => 'sports-monthly-trial',
                 :price_list             => 'DEFAULT',
                 :service_name           => 'entitlement-service',
                 :service_state_name     => 'ENT_STARTED'},
                {:type                   => 'START_BILLING',
                 :date                   => DEFAULT_KB_INIT_DATE,
                 :billing_period         => 'MONTHLY',
                 :product                => 'Sports',
                 :plan                   => 'sports-monthly',
                 :phase                  => 'sports-monthly-trial',
                 :price_list             => 'DEFAULT',
                 :service_name           => 'billing-service',
                 :service_state_name     => 'START_BILLING'},
                {:type                   => 'PHASE',
                 :date                   => '2013-08-31',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Sports',
                 :plan                   => 'sports-monthly',
                 :phase                  => 'sports-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :service_name           => 'entitlement+billing-service',
                 :service_state_name     => 'PHASE'},
                {:type                   => 'STOP_ENTITLEMENT',
                 :date                   => '2013-09-01',
                 :service_name           => 'entitlement-service',
                 :service_state_name     => 'ENT_CANCELLED'},
                {:type                   => 'STOP_BILLING',
                 :date                   => '2013-09-30',
                 :service_name           => 'billing-service',
                 :service_state_name     => 'STOP_BILLING'}]

      check_events(events, bp.events)

    end

    # Cancellation with with explicit entitlement imm policy
    def test_bp_cancel_entitlement_imm
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Cancel BP  in trial with no arguments
      requested_date = nil
      entitlement_policy = "IMMEDIATE"
      billing_policy = nil
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      canceled_bp = get_subscription(bp.subscription_id, @options)
      check_entitlement(canceled_bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, DEFAULT_KB_INIT_DATE)

      canceled_bp = get_subscription(bp.subscription_id, @options)
      check_subscription(canceled_bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, DEFAULT_KB_INIT_DATE, DEFAULT_KB_INIT_DATE, DEFAULT_KB_INIT_DATE)
    end

    # Cancellation with with explicit entitlement eot policy
    def test_bp_cancel_entitlement_eot
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock after the trial to have a CTD
      kb_clock_add_days(31, nil, @options)

      # Cancel BP  in trial with no arguments
      requested_date = nil
      entitlement_policy = "END_OF_TERM"
      billing_policy = nil
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      canceled_bp = get_subscription(bp.subscription_id, @options)
      check_subscription(canceled_bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")
    end

    # Cancellation with with explicit requested date in the future
    def test_bp_cancel_entitlement_with_requested_date_in_future_ent_only
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock after the trial to have a CTD
      kb_clock_add_days(31, nil, @options)

      # Cancel BP  in trial with no arguments
      requested_date = "2013-09-15"
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = false

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      canceled_bp = get_subscription(bp.subscription_id, @options)
      check_subscription(canceled_bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, requested_date, DEFAULT_KB_INIT_DATE,  "2013-09-30")
    end

    def test_bp_cancel_entitlement_with_requested_date_in_future_both
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock after the trial to have a CTD
      kb_clock_add_days(31, nil, @options)

      # Cancel BP  in trial with no arguments
      requested_date = "2013-09-15"
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = true

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      canceled_bp = get_subscription(bp.subscription_id, @options)
      check_subscription(canceled_bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, requested_date, DEFAULT_KB_INIT_DATE, requested_date)
    end

    # Cancellation with with explicit billing policy
    def test_bp_cancel_billing_imm
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock a few days ahead
      kb_clock_add_days(10, nil, @options)

      # We specify a requested_date which is in between the start_date and the current date to verify
      # this is has been  honored
      requested_date = "2013-08-05"
      entitlement_policy = nil
      billing_policy = "IMMEDIATE"
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)


      canceled_bp = get_subscription(bp.subscription_id, @options)
      check_subscription(canceled_bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, requested_date, DEFAULT_KB_INIT_DATE, "2013-08-11")
    end

    # Cancellation with with explicit billing policy with ctd
    def test_bp_cancel_billing_eot_with_ctd
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock a few days ahead
      kb_clock_add_days(31, nil, @options)
      bp2 = get_subscription(bp.subscription_id, @options)
      assert_equal("2013-09-30", bp2.charged_through_date)

      requested_date = "2013-08-05"
      entitlement_policy = nil
      billing_policy = "END_OF_TERM"
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)


      canceled_bp = get_subscription(bp.subscription_id, @options)
      check_subscription(canceled_bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, requested_date, DEFAULT_KB_INIT_DATE, "2013-09-30")
    end

    # Cancellation with with explicit billing policy with ctd
    def test_bp_cancel_entitlement_eot_billing_eot_with_ctd
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock after trial
      kb_clock_add_days(31, nil, @options)

      bp2 = get_subscription(bp.subscription_id, @options)
      assert_equal("2013-09-30", bp2.charged_through_date)

      requested_date = "2013-08-05"
      entitlement_policy = "END_OF_TERM"
      billing_policy = "END_OF_TERM"
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)


      canceled_bp = get_subscription(bp.subscription_id, @options)
      check_subscription(canceled_bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, "2013-09-30", DEFAULT_KB_INIT_DATE, "2013-09-30")
    end

  end
end
