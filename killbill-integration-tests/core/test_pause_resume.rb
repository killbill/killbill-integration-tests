# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'test_base'

module KillBillIntegrationTests
  class TestPauseResume < Base
    def setup
      setup_base
      load_default_catalog

      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)
    end

    def teardown
      teardown_base
    end

    def test_basic
      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Second invoice
      # Move clock  (BP out of trial)
      kb_clock_add_days(30, nil, @options) # 31/08/2013

      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(@options)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 500.00, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Move clock  and pause bundle
      kb_clock_add_days(5, nil, @options) # 5/09/2013
      pause_bundle(bp.bundle_id, nil, @user, @options)

      # Verify new invoice is generated for when we block
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(@options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)

      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 500.00, 'USD', '2013-08-31')
      assert_equal(1, second_invoice.items.size)
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, -416.67, 'USD', '2013-09-05')
      assert_equal(2, third_invoice.items.size)
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, -416.67, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 416.67, 'USD', 'CBA_ADJ', nil, nil, '2013-09-05', '2013-09-05')

      # Move clock
      kb_clock_add_days(5, nil, @options) # 10/09/2013
      resume_bundle(bp.bundle_id, nil, @user, @options)

      # Verify new invoice is generated for when we unblock
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(@options)
      assert_equal(4, all_invoices.size)
      sort_invoices!(all_invoices)

      fourth_invoice = all_invoices[3]
      check_invoice_no_balance(fourth_invoice, 322.58, 'USD', '2013-09-10')
      assert_equal(2, fourth_invoice.items.size)
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, 322.58, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-10', '2013-09-30')
      check_invoice_item(fourth_invoice.items[1], fourth_invoice.invoice_id, -322.58, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(1, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-08-01' },
                    { type: 'START_BILLING', date: '2013-08-01' },
                    { type: 'PHASE', date: '2013-08-31' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-09-05' },
                    { type: 'PAUSE_BILLING', date: '2013-09-05' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-09-10' },
                    { type: 'RESUME_BILLING', date: '2013-09-10' }], bp.events)
    end

    # https://github.com/killbill/killbill/issues/258
    def test_pause_resume_same_day
      # First invoice 2013-08-01 -> 2013-08-31 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Move clock 1 day (2013-08-02)
      kb_clock_add_days(1, nil, @options)

      # Pause bundle
      pause_bundle(bp.bundle_id, nil, @user, @options)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(1, subscriptions.size)
      bp = subscriptions.first
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-08-01' },
                    { type: 'START_BILLING', date: '2013-08-01' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'PHASE', date: '2013-08-31' }], bp.events)

      # Resume bundle today
      resume_bundle(bp.bundle_id, nil, @user, @options)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(1, subscriptions.size)
      bp = subscriptions.first
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-08-01' },
                    { type: 'START_BILLING', date: '2013-08-01' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PHASE', date: '2013-08-31' }], bp.events)

      # Pause bundle again
      pause_bundle(bp.bundle_id, nil, @user, @options)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(1, subscriptions.size)
      bp = subscriptions.first
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-08-01' },
                    { type: 'START_BILLING', date: '2013-08-01' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'PHASE', date: '2013-08-31' }], bp.events)

      # Resume bundle again
      resume_bundle(bp.bundle_id, nil, @user, @options)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(1, subscriptions.size)
      bp = subscriptions.first
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-08-01' },
                    { type: 'START_BILLING', date: '2013-08-01' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PHASE', date: '2013-08-31' }], bp.events)

      # Pause bundle again
      pause_bundle(bp.bundle_id, nil, @user, @options)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(1, subscriptions.size)
      bp = subscriptions.first
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-08-01' },
                    { type: 'START_BILLING', date: '2013-08-01' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'PHASE', date: '2013-08-31' }], bp.events)

      # Resume bundle again
      resume_bundle(bp.bundle_id, nil, @user, @options)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(1, subscriptions.size)
      bp = subscriptions.first
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-08-01' },
                    { type: 'START_BILLING', date: '2013-08-01' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PHASE', date: '2013-08-31' }], bp.events)

      # Move clock (BP out of trial)
      kb_clock_add_days(29, nil, @options) # 31/08/2013

      # Verify invoices
      all_invoices  = check_next_invoice_amount(2, 500, '2013-08-31', @account, @options, &@proc_account_invoices_nb)
      first_invoice = all_invoices[0]
      assert_equal(1, first_invoice.items.size, "Invalid number of invoice items: #{first_invoice.items.size}")
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2013-08-01', '2013-08-31')
      second_invoice = all_invoices[1]
      assert_equal(1, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Pause bundle again
      pause_bundle(bp.bundle_id, nil, @user, @options)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(1, subscriptions.size)
      bp = subscriptions.first
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-08-01' },
                    { type: 'START_BILLING', date: '2013-08-01' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PHASE', date: '2013-08-31' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-31' },
                    { type: 'PAUSE_BILLING', date: '2013-08-31' }], bp.events)

      # Verify invoices
      all_invoices  = check_next_invoice_amount(3, -500, '2013-08-31', @account, @options, &@proc_account_invoices_nb)
      first_invoice = all_invoices[0]
      assert_equal(1, first_invoice.items.size, "Invalid number of invoice items: #{first_invoice.items.size}")
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2013-08-01', '2013-08-31')
      second_invoice = all_invoices[1]
      assert_equal(1, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      third_invoice = all_invoices[2]
      assert_equal(2, third_invoice.items.size, "Invalid number of invoice items: #{third_invoice.items.size}")
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, -500, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-31', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 500, 'USD', 'CBA_ADJ', nil, nil, '2013-08-31', '2013-08-31')

      # Resume bundle again
      resume_bundle(bp.bundle_id, nil, @user, @options)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_equal(1, subscriptions.size)
      bp = subscriptions.first
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-08-01' },
                    { type: 'START_BILLING', date: '2013-08-01' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'PAUSE_BILLING', date: '2013-08-02' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-02' },
                    { type: 'RESUME_BILLING', date: '2013-08-02' },
                    { type: 'PHASE', date: '2013-08-31' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-08-31' },
                    { type: 'PAUSE_BILLING', date: '2013-08-31' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-08-31' },
                    { type: 'RESUME_BILLING', date: '2013-08-31' }], bp.events)
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)

      # Move clock 1 day to check nothing happens (2013-09-01)
      kb_clock_add_days(1, nil, @options)

      # Verify invoices
      all_invoices  = check_next_invoice_amount(4, 500, '2013-08-31', @account, @options, &@proc_account_invoices_nb)
      first_invoice = all_invoices[0]
      assert_equal(1, first_invoice.items.size, "Invalid number of invoice items: #{first_invoice.items.size}")
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2013-08-01', '2013-08-31')
      second_invoice = all_invoices[1]
      assert_equal(1, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      third_invoice = all_invoices[2]
      assert_equal(2, third_invoice.items.size, "Invalid number of invoice items: #{third_invoice.items.size}")
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, -500, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-31', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 500, 'USD', 'CBA_ADJ', nil, nil, '2013-08-31', '2013-08-31')
      fourth_invoice = all_invoices[3]
      assert_equal(2, fourth_invoice.items.size, "Invalid number of invoice items: #{fourth_invoice.items.size}")
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, -500, 'USD', 'CBA_ADJ', nil, nil, '2013-08-31', '2013-08-31')
      check_invoice_item(fourth_invoice.items[1], fourth_invoice.invoice_id, 500, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
    end

    def test_pause_resume_in_the_past
      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Second invoice
      # Move clock  (BP out of trial)
      kb_clock_add_days(30, nil, @options) # 31/08/2013

      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(@options)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 500.00, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Third invoice
      # Move clock
      kb_clock_add_days(30, nil, @options) # 30/09/2013
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(@options)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 500.00, 'USD', '2013-09-30')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-30', '2013-10-31')

      # Move clock to make sure both pause and resume are in the past, but before 31/10/2013 so as to not re-trigger new invoice
      kb_clock_add_days(30, nil, @options) # 30/10/2013

      # Disable invoice processing for account
      @account.set_auto_invoicing_off(@user, 'test_pause_resume_in_the_past', 'Disable invoice prior pause/resume', @options)

      # Pause bundle in the past
      pause_bundle(bp.bundle_id, '2013-09-15', @user, @options)

      # Resume bundle in the past
      resume_bundle(bp.bundle_id, '2013-10-15', @user, @options)

      @account.remove_auto_invoicing_off(@user, 'test_pause_resume_in_the_past', 'Re-enable invoice prior pause/resume', @options)

      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(@options)
      sort_invoices!(all_invoices)
      fourth_invoice = all_invoices[3]

      check_invoice_item(get_specific_invoice_item(fourth_invoice.items, 'CBA_ADJ', 491.94), fourth_invoice.invoice_id, 491.94, 'USD', 'CBA_ADJ', nil, nil, '2013-10-30', '2013-10-30')
      check_invoice_item(get_specific_invoice_item(fourth_invoice.items, 'REPAIR_ADJ', -250.00), fourth_invoice.invoice_id, -250.00, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-15', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(fourth_invoice.items, 'REPAIR_ADJ', -241.94), fourth_invoice.invoice_id, -241.94, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-30', '2013-10-15')
    end

    def test_with_ao
      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Second invoice
      # Move clock  (BP out of trial)
      kb_clock_add_days(30, nil, @options) # 31/08/2013

      all_invoices = @account.invoices(@options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 500.00, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Move clock  and create ao
      # Third invoice : 2/09/2013 -> 30/09/2013
      kb_clock_add_days(2, nil, @options) # 2/09/2013
      ao1 = create_entitlement_ao(@account.account_id, bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', '2013-09-02', nil)

      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(@options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 7.18, 'USD', '2013-09-02')
      assert_equal(1, third_invoice.items.size)
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 7.18, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-evergreen', '2013-09-02', '2013-09-30')

      # Move clock  and pause bundle
      kb_clock_add_days(3, nil, @options) # 5/09/2013
      pause_bundle(bp.bundle_id, nil, @user, @options)

      # Verify we generated a new invoice
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(@options)
      assert_equal(4, all_invoices.size)
      sort_invoices!(all_invoices)

      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 500.0, 'USD', '2013-08-31')
      assert_equal(1, second_invoice.items.size)
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 7.18, 'USD', '2013-09-02')
      assert_equal(1, third_invoice.items.size)
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 7.18, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-evergreen', '2013-09-02', '2013-09-30')

      fourth_invoice = all_invoices[3]
      check_invoice_no_balance(fourth_invoice, -423.08, 'USD', '2013-09-05')
      assert_equal(3, fourth_invoice.items.size)
      check_invoice_item(get_specific_invoice_item(fourth_invoice.items, 'REPAIR_ADJ', -416.67), fourth_invoice.invoice_id, -416.67, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(fourth_invoice.items, 'REPAIR_ADJ', -6.41), fourth_invoice.invoice_id, -6.41, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(fourth_invoice.items, 'CBA_ADJ', 423.08), fourth_invoice.invoice_id, 423.08, 'USD', 'CBA_ADJ', nil, nil, '2013-09-05', '2013-09-05')

      # Move clock
      kb_clock_add_days(5, nil, @options) # 10/09/2013
      resume_bundle(bp.bundle_id, nil, @user, @options)

      # Verify last invoice was adjusted
      wait_for_expected_clause(5, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(@options)
      assert_equal(5, all_invoices.size)
      sort_invoices!(all_invoices)
      fifth_invoice = all_invoices[4]
      check_invoice_no_balance(fifth_invoice, 327.71, 'USD', '2013-09-10')
      assert_equal(3, fifth_invoice.items.size)
      check_invoice_item(get_specific_invoice_item(fifth_invoice.items, 'RECURRING', 'oilslick-monthly-evergreen'), fifth_invoice.invoice_id, 5.13, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-evergreen', '2013-09-10', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(fifth_invoice.items, 'RECURRING', 'sports-monthly-evergreen'), fifth_invoice.invoice_id, 322.58, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-10', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(fifth_invoice.items, 'CBA_ADJ', -327.71), fifth_invoice.invoice_id, -327.71, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-08-01' },
                    { type: 'START_BILLING', date: '2013-08-01' },
                    { type: 'PHASE', date: '2013-08-31' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-09-05' },
                    { type: 'PAUSE_BILLING', date: '2013-09-05' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-09-10' },
                    { type: 'RESUME_BILLING', date: '2013-09-10' }], bp.events)

      # No DISCOUNT phase as we started he subscription more than a month after BP and this is bundle aligned.
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', '2013-09-02', nil, '2013-09-02', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-09-02' },
                    { type: 'START_BILLING', date: '2013-09-02' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-09-05' },
                    { type: 'PAUSE_BILLING', date: '2013-09-05' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-09-10' },
                    { type: 'RESUME_BILLING', date: '2013-09-10' }], ao1.events)
    end

    def test_future_pause
      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Second invoice
      # Move clock  (BP out of trial)
      kb_clock_add_days(30, nil, @options) # 31/08/2013

      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(@options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]

      check_invoice_no_balance(second_invoice, 500.00, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Pause in the future
      pause_bundle(bp.bundle_id, '2013-09-05', @user, @options)

      # Here all we can do is wait; we are waiting to check there is NO change in the system, no nothing to check against
      wait_for_killbill(@options)
      all_invoices = @account.invoices(@options)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      assert_equal(1, second_invoice.items.size)

      # Check the subscription is marked as PAUSED in the future
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      bp            = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)

      # BUG : future pause events are not returned
      # check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
      #              {:type => "START_BILLING", :date => "2013-08-01"},
      #              {:type => "PHASE", :date => "2013-08-31"},
      #              {:type => "PAUSE_ENTITLEMENT", :date => "2013-09-05"},
      #              {:type => "PAUSE_BILLING", :date => "2013-09-05"}], bp.events)

      # Move clock to reach pause
      kb_clock_add_days(5, nil, @options) # 5/09/2013

      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(@options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)

      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 500.00, 'USD', '2013-08-31')
      assert_equal(1, second_invoice.items.size)
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, -416.67, 'USD', '2013-09-05')
      assert_equal(2, third_invoice.items.size)
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, -416.67, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 416.67, 'USD', 'CBA_ADJ', nil, nil, '2013-09-05', '2013-09-05')

      # Move clock
      kb_clock_add_days(5, nil, @options) # 10/09/2013
      resume_bundle(bp.bundle_id, nil, @user, @options)

      # Verify we generate a new invoice
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(@options)
      assert_equal(4, all_invoices.size)
      sort_invoices!(all_invoices)

      fourth_invoice = all_invoices[3]
      check_invoice_no_balance(fourth_invoice, 322.58, 'USD', '2013-09-10')
      assert_equal(2, fourth_invoice.items.size)
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, 322.58, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-10', '2013-09-30')
      check_invoice_item(fourth_invoice.items[1], fourth_invoice.invoice_id, -322.58, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(1, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil, '2013-08-01', nil)
      check_events([{ type: 'START_ENTITLEMENT', date: '2013-08-01' },
                    { type: 'START_BILLING', date: '2013-08-01' },
                    { type: 'PHASE', date: '2013-08-31' },
                    { type: 'PAUSE_ENTITLEMENT', date: '2013-09-05' },
                    { type: 'PAUSE_BILLING', date: '2013-09-05' },
                    { type: 'RESUME_ENTITLEMENT', date: '2013-09-10' },
                    { type: 'RESUME_BILLING', date: '2013-09-10' }], bp.events)
    end
  end
end
