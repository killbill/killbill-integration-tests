# encoding: utf-8

$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestEntitlementChangePlanTest < Base

    def setup
      setup_base
      load_default_catalog
      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    def test_change_default

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      kb_clock_add_days(1, nil, @options)

      # Change plan
      requested_date = nil
      billing_policy = nil
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, nil, false, @options)
      check_entitlement(bp, 'Super', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      changed_bp = get_subscription(bp.subscription_id, @options)
      assert_not_nil(changed_bp)
      assert_nil(changed_bp.cancelled_date)
      assert_nil(changed_bp.billing_end_date)

      events = get_events(@account.account_id, changed_bp.subscription_id)
      assert_equal(events.size, 4)
      assert_equal(events[0].effective_date, DEFAULT_KB_INIT_DATE)
      assert_equal(events[0].event_type, "START_ENTITLEMENT")
      assert_equal(events[1].effective_date, DEFAULT_KB_INIT_DATE)
      assert_equal(events[1].event_type, "START_BILLING")
      assert_equal(events[2].effective_date, "2013-08-02")
      assert_equal(events[2].event_type, "CHANGE")
      assert_equal(events[3].effective_date, "2013-08-31")
      assert_equal(events[3].event_type, "PHASE")
    end

    def test_change_with_date

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Move clock after requested_date
      kb_clock_add_days(7, nil, @options)

      # Change plan
      requested_date = "2013-08-05"
      billing_policy = nil
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, nil, false, @options)
      assert_equal(bp.product_name, 'Super')
      assert_equal(bp.product_category, 'BASE')
      assert_equal(bp.billing_period, 'MONTHLY')
      assert_equal(bp.price_list, 'DEFAULT')
      assert_nil(bp.cancelled_date)

      changed_bp = get_subscription(bp.subscription_id, @options)
      assert_not_nil(changed_bp)
      assert_nil(changed_bp.cancelled_date)
      assert_nil(changed_bp.billing_end_date)

      events = get_events(@account.account_id, changed_bp.subscription_id)
      assert_equal(events.size, 4)
      assert_equal(events[0].effective_date, DEFAULT_KB_INIT_DATE)
      assert_equal(events[0].event_type, "START_ENTITLEMENT")
      assert_equal(events[1].effective_date, DEFAULT_KB_INIT_DATE)
      assert_equal(events[1].event_type, "START_BILLING")
      assert_equal(events[2].effective_date, requested_date)
      assert_equal(events[2].event_type, "CHANGE")
      assert_equal(events[3].effective_date, "2013-08-31")
      assert_equal(events[3].event_type, "PHASE")

    end


    def test_change_with_policy_eot

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Move clock after trial
      kb_clock_add_days(31, nil, @options)

      # Change plan
      requested_date = nil
      billing_policy = "END_OF_TERM"
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, nil, false, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      changed_bp = get_subscription(bp.subscription_id, @options)
      assert_not_nil(changed_bp)
      assert_nil(changed_bp.cancelled_date)
      assert_nil(changed_bp.billing_end_date)


      events = get_events(@account.account_id, changed_bp.subscription_id)
      assert_equal(events.size, 4)
      assert_equal(events[0].effective_date, DEFAULT_KB_INIT_DATE)
      assert_equal(events[0].event_type, "START_ENTITLEMENT")
      assert_equal(events[1].effective_date, DEFAULT_KB_INIT_DATE)
      assert_equal(events[1].event_type, "START_BILLING")
      assert_equal(events[2].effective_date, "2013-08-31")
      assert_equal(events[2].event_type, "PHASE")
      assert_equal(events[3].effective_date, "2013-09-30")
      assert_equal(events[3].event_type, "CHANGE")

    end


    private

    def get_events(account_id, subscription_id)
      timeline = get_account_timeline(account_id, @options)
      assert_not_nil(timeline)
      assert_not_nil(timeline.bundles)
      assert_equal(timeline.bundles.size, 1)

      bundle = timeline.bundles[0]
      assert_equal(bundle.subscriptions.size, 1)

      subscriptions = bundle.subscriptions
      assert_equal(subscriptions.size, 1)
      subscription = subscriptions[0]

      assert_equal(subscription.subscription_id, subscription_id)
      assert_not_nil(subscription.events)
      subscription.events
    end
  end
end
