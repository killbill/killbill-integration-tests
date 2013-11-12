$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestEntitlementAddOn < Base

    def setup
      @user = "EntitlementAddOn"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
    end

    def teardown
      teardown_base
    end

=begin
    def test_simple

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', nil)

      # Create Add-on
      ao_entitlement = create_entitlement_ao(bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', nil)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
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

    def test_cancel_bp_imm

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', nil)

      # Move clock to create ADD_ON a bit later (BP still in trial)
      kb_clock_add_days(15, nil, @options)

      # Create Add-on
      ao_entitlement = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', nil)

      # Move clock before cancellation (BP still in trial)
      kb_clock_add_days(5, nil, @options)

      # All default, system will cancel immediately since we are still in trial
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(subscriptions.size, 2)

      bps = subscriptions.reject { |s| s.product_category == 'ADD_ON' }
      assert_not_nil(bps)
      assert_equal(bps.size, 1)
      assert_equal(bps[0].subscription_id , bp.subscription_id)
      assert_equal(bps[0].start_date , "2013-08-01")
      assert_equal(bps[0].billing_start_date , "2013-08-01")
      assert_equal(bps[0].cancelled_date , "2013-08-21")
      assert_equal(bps[0].billing_end_date , "2013-08-21")
      assert_equal(bps[0].events.size , 4)
      assert_equal(bps[0].events[0].event_type , "START_ENTITLEMENT")
      assert_equal(bps[0].events[0].effective_date , "2013-08-01")
      assert_equal(bps[0].events[1].event_type , "START_BILLING")
      assert_equal(bps[0].events[1].effective_date , "2013-08-01")
      assert_equal(bps[0].events[2].event_type , "STOP_ENTITLEMENT")
      assert_equal(bps[0].events[2].effective_date , "2013-08-21")
      assert_equal(bps[0].events[3].event_type , "STOP_BILLING")
      assert_equal(bps[0].events[3].effective_date , "2013-08-21")

      aos = subscriptions.reject { |s| s.product_category == 'BASE' }
      assert_not_nil(aos)
      assert_equal(aos.size, 1)
      assert_equal(aos[0].subscription_id , ao_entitlement.subscription_id)
      assert_equal(aos[0].start_date , "2013-08-16")
      assert_equal(aos[0].billing_start_date , "2013-08-16")
      assert_equal(aos[0].cancelled_date , "2013-08-21")
      assert_equal(aos[0].billing_end_date , "2013-08-21")
      assert_equal(aos[0].events.size , 4)
      assert_equal(aos[0].events[0].event_type , "START_ENTITLEMENT")
      assert_equal(aos[0].events[0].effective_date , "2013-08-16")
      assert_equal(aos[0].events[1].event_type , "START_BILLING")
      assert_equal(aos[0].events[1].effective_date , "2013-08-16")
      assert_equal(aos[0].events[2].event_type , "STOP_ENTITLEMENT")
      assert_equal(aos[0].events[2].effective_date , "2013-08-21")
      assert_equal(aos[0].events[3].event_type , "STOP_BILLING")
      assert_equal(aos[0].events[3].effective_date , "2013-08-21")
    end


    def test_cancel_bp_eot

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', nil)

      # Move clock to create ADD_ON a bit later (BP still in trial)
      kb_clock_add_days(15, nil, @options)

      # Create Add-on
      ao_entitlement = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', nil)

      # Move clock after trial before cancellation
      kb_clock_add_days(16, nil, @options)

      # All default, system will cancel IMM for entitlement and billing EOT since we are past trial
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(subscriptions.size, 2)

      bps = subscriptions.reject { |s| s.product_category == 'ADD_ON' }
      assert_not_nil(bps)
      assert_equal(bps.size, 1)
      assert_equal(bps[0].subscription_id , bp.subscription_id)
      assert_equal(bps[0].start_date , "2013-08-01")
      assert_equal(bps[0].billing_start_date , "2013-08-01")
      assert_equal(bps[0].cancelled_date , "2013-09-01")
      assert_equal(bps[0].billing_end_date , "2013-09-30")
      assert_equal(bps[0].events.size , 5)
      assert_equal(bps[0].events[0].event_type , "START_ENTITLEMENT")
      assert_equal(bps[0].events[0].effective_date , "2013-08-01")
      assert_equal(bps[0].events[1].event_type , "START_BILLING")
      assert_equal(bps[0].events[1].effective_date , "2013-08-01")
      assert_equal(bps[0].events[2].event_type , "PHASE")
      assert_equal(bps[0].events[2].effective_date , "2013-08-31")
      assert_equal(bps[0].events[3].event_type , "STOP_ENTITLEMENT")
      assert_equal(bps[0].events[3].effective_date , "2013-09-01")
      assert_equal(bps[0].events[4].event_type , "STOP_BILLING")
      assert_equal(bps[0].events[4].effective_date , "2013-09-30")

      aos = subscriptions.reject { |s| s.product_category == 'BASE' }
      assert_not_nil(aos)
      assert_equal(aos.size, 5)
      assert_equal(aos[0].subscription_id , ao_entitlement.subscription_id)
      assert_equal(aos[0].start_date , "2013-08-16")
      assert_equal(aos[0].billing_start_date , "2013-08-16")
      assert_equal(aos[0].cancelled_date , "2013-09-01")
      assert_equal(aos[0].billing_end_date , "2013-09-30")
      assert_equal(aos[0].events.size , 5)
      assert_equal(aos[0].events[0].event_type , "START_ENTITLEMENT")
      assert_equal(aos[0].events[0].effective_date , "2013-08-16")
      assert_equal(aos[0].events[1].event_type , "START_BILLING")
      assert_equal(aos[0].events[1].effective_date , "2013-08-16")
      assert_equal(aos[0].events[2].event_type , "PHASE")
      assert_equal(aos[0].events[2].effective_date , "2013-09-01")
      assert_equal(aos[0].events[3].event_type , "STOP_ENTITLEMENT")
      assert_equal(aos[0].events[3].effective_date , "2013-09-01")
      assert_equal(aos[0].events[4].event_type , "STOP_BILLING")
      assert_equal(aos[0].events[4].effective_date , "2013-09-30")
    end
=end

=begin

** Base plan started at t1
** Add-on A started at t1
** Add-on A cancelled at t2
** Add-on B started at t2
** Base and add-on B phases aligned at t3
-> check add-on A was cancelled at t2, add-on B is not cancelled and we don't have duplicated events for add-on A
** Future cancel add-on B at t4
** Move the clock to t5
-> check add-on A was cancelled at t2, add-on B was cancelled at t4 and we don't have duplicated events

=end


    def test_separate_ao_cancel

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', nil)

      # Create Add-on 1
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', nil)

      # Move clock after before cancellation (BP still in trial)
      kb_clock_add_days(3, nil, @options)

      # All default, system will cancel IMM for entitlement and billing EOT since we are past trial
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil

      ao1.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(subscriptions.size, 2)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal(ao1.start_date , "2013-08-01")
      assert_equal(ao1.billing_start_date , "2013-08-01")
      assert_equal(ao1.cancelled_date , "2013-08-04")
      assert_equal(ao1.billing_end_date , "2013-08-04")

      # Create Add-on 2
      ao2 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao2, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', nil)


      requested_date = nil
      entitlement_policy = "END_OF_TERM"
      billing_policy = "END_OF_TERM"
      use_requested_date_for_billing = nil

      ao2.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(subscriptions.size, 3)

      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      assert_equal(ao1.start_date , "2013-08-01")
      assert_equal(ao1.billing_start_date , "2013-08-01")
      assert_equal(ao1.cancelled_date , "2013-08-04")
      assert_equal(ao1.billing_end_date , "2013-08-04")

      ao2 = subscriptions.find { |s| s.subscription_id == ao2.subscription_id }
      assert_equal(ao2.start_date , "2013-08-04")
      assert_equal(ao2.billing_start_date , "2013-08-04")
      assert_equal(ao2.cancelled_date , "2013-08-31")
      assert_equal(ao2.billing_end_date , "2013-08-31")

    end


  end
end

