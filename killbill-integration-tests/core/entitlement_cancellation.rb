$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class EntitlementCancellationTest < Base

    def setup
      @user = "EntitlementCancellationTest"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
    end

    def teardown
      teardown_base
    end

    # Cancellation with with explicit no arguments
    def test_bp_cancel_default
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Cancel BP  in trial with no arguments
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, @options)

      canceled_bp = get_entitlement(bp.subscription_id, @options)
      assert_not_nil(canceled_bp)
      assert_not_nil(canceled_bp.cancelled_date, DEFAULT_KB_INIT_DATE)
      assert_not_nil(canceled_bp.billing_end_date, DEFAULT_KB_INIT_DATE)
    end

    # Cancellation with with explicit entitlement imm policy
    def test_bp_cancel_entitlement_imm
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Cancel BP  in trial with no arguments
      requested_date = nil
      entitlement_policy = "IMMEDIATE"
      billing_policy = nil
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, @options)

      canceled_bp = get_entitlement(bp.subscription_id, @options)
      assert_not_nil(canceled_bp)
      assert_not_nil(canceled_bp.cancelled_date, DEFAULT_KB_INIT_DATE)

      canceled_bp = get_subscription(bp.subscription_id, @options)
      assert_not_nil(canceled_bp)
      assert_not_nil(canceled_bp.cancelled_date, DEFAULT_KB_INIT_DATE)
      assert_not_nil(canceled_bp.billing_end_date, DEFAULT_KB_INIT_DATE)
    end

    # Cancellation with with explicit entitlement eot policy
    def test_bp_cancel_entitlement_eot
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Move clock after the trial to have a CTD
      kb_clock_add_days(31, nil, @options)

      # Cancel BP  in trial with no arguments
      requested_date = nil
      entitlement_policy = "END_OF_TERM"
      billing_policy = nil
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, @options)

      canceled_bp = get_subscription(bp.subscription_id, @options)
      assert_not_nil(canceled_bp)
      assert_not_nil(canceled_bp.cancelled_date, "2013-09-30")
      assert_not_nil(canceled_bp.billing_end_date, DEFAULT_KB_INIT_DATE)
    end

    # Cancellation with with explicit requested date in the future
    def test_bp_cancel_entitlement_with_requested_date_in_future
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Move clock after the trial to have a CTD
      kb_clock_add_days(31, nil, @options)

      # Cancel BP  in trial with no arguments
      requested_date = "2013-09-15"
      entitlement_policy = nil
      billing_policy = nil
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, @options)

      canceled_bp = get_subscription(bp.subscription_id, @options)
      assert_not_nil(canceled_bp)
      assert_not_nil(canceled_bp.cancelled_date, DEFAULT_KB_INIT_DATE)
      assert_not_nil(canceled_bp.billing_end_date, DEFAULT_KB_INIT_DATE)
    end

    # Cancellation with with explicit billing policy
    def test_bp_cancel_billing_imm
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Move clock a few days ahead
      kb_clock_add_days(10, nil, @options)

      # We specify a requested_date which is in between the start_date and the current date to verify
      # this is has been  honored
      requested_date = "2013-08-05"
      entitlement_policy = nil
      billing_policy = "IMMEDIATE"
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, @options)


      canceled_bp = get_subscription(bp.subscription_id, @options)
      assert_not_nil(canceled_bp)
      assert_not_nil(canceled_bp.cancelled_date, DEFAULT_KB_INIT_DATE)
      assert_not_nil(canceled_bp.billing_end_date, "2013-08-05")
    end


    # Cancellation with with explicit billing policy with ctd
    def test_bp_cancel_billing_eot_no_ctd
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Move clock a few days ahead
      kb_clock_add_days(10, nil, @options)

      requested_date = "2013-08-05"
      entitlement_policy = nil
      billing_policy = "END_OF_TERM"
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, @options)


      canceled_bp = get_subscription(bp.subscription_id, @options)
      assert_not_nil(canceled_bp)
      assert_not_nil(canceled_bp.cancelled_date, DEFAULT_KB_INIT_DATE)
      assert_not_nil(canceled_bp.billing_end_date, "2013-08-05")
    end

    # Cancellation with with explicit billing policy with ctd
    def test_bp_cancel_billing_eot_with_ctd
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Move clock a few days ahead
      kb_clock_add_days(31, nil, @options)

      requested_date = "2013-08-05"
      entitlement_policy = nil
      billing_policy = "END_OF_TERM"
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, @options)


      canceled_bp = get_subscription(bp.subscription_id, @options)
      assert_not_nil(canceled_bp)
      assert_not_nil(canceled_bp.cancelled_date, DEFAULT_KB_INIT_DATE)
      assert_not_nil(canceled_bp.billing_end_date, "2013-09-30")
    end

    # Cancellation with with explicit billing policy with ctd
    def test_bp_cancel_entitlement_eot_billing_eot_with_ctd
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Move clock after trial
      kb_clock_add_days(31, nil, @options)

      requested_date = "2013-08-05"
      entitlement_policy = "END_OF_TERM"
      billing_policy = "END_OF_TERM"
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, @options)


      canceled_bp = get_subscription(bp.subscription_id, @options)
      assert_not_nil(canceled_bp)
      assert_not_nil(canceled_bp.cancelled_date, "2013-09-30")
      assert_not_nil(canceled_bp.billing_end_date, "2013-09-30")
    end

  end
end