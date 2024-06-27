# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'test_base'

module KillBillIntegrationTests
  class TestWithDatesAndTimezones < Base
    #
    # For all tests we chose a clock init date at least one day after effective_date of catalog since some tests uses a timezone with -11 hours, which
    # means the first invoice in account timezone would be in 2013-08-01, and so we need to have a valid catalog
    #
    def setup; end

    def teardown
      teardown_base
    end

    def test_create_subscription_with_tz_minus_11_no_requested_date
      # No requested date -> will take today's date (and all conversion in account timezone will lead to '2013-08-01' and NOT '2013-08-02')
      test_scenario_fixed_price('2013-08-02T06:00:00.000Z', 'Pacific/Samoa', nil, '2013-08-01', '2013-08-01', '2013-08-31')
    end

    def test_create_subscription_with_tz_minus_11_with_requested_date_today
      # Requested date of '2013-08-01'  will also take today's date (and all conversion in account timezone will lead to '2013-08-01' and NOT '2013-08-02')
      test_scenario_fixed_price('2013-08-02T06:00:00.000Z', 'Pacific/Samoa', '2013-08-01', '2013-08-01', '2013-08-01', '2013-08-31')
    end

    def test_create_subscription_with_tz_minus_11_with_requested_date_in_slight_future
      # Requested date of '2013-08-02' means that this is a future date (in account timezone time is "2013-08-01T19:00:00.000-11")
      # There is a trick here which is that we end up with a date in the future so we need to move the clock before we can retrieve the invoice
      test_scenario_fixed_price_with_future_invoice('2013-08-02T06:00:00.000Z', 'Pacific/Samoa', '2013-08-02', '2013-08-02', '2013-08-02','2013-09-01', 1)
    end

    def test_create_subscription_with_tz_plus_9_no_requested_date
      # No requested date -> will take today's date (and all conversion in account timezone will lead to '2013-08-03' and NOT '2013-08-02')
      test_scenario_fixed_price('2013-08-02T18:00:00.000Z', 'Asia/Tokyo', nil, '2013-08-03', '2013-08-03', '2013-09-02')
    end

    def test_create_subscription_with_tz_plus_9_with_requested_date_today
      #  Requested date of '2013-08-03'  will take today's date (and all conversion in account timezone will lead to '2013-08-03' and NOT '2013-08-02')
      test_scenario_fixed_price('2013-08-02T18:00:00.000Z', 'Asia/Tokyo', '2013-08-03', '2013-08-03', '2013-08-03', '2013-09-02')
    end

    def test_create_subscription_with_tz_plus_9_with_requested_date_in_slight_past
      # Requested date of '2013-08-02' means that this is a date in the past (in account timezone time is "2013-08-03T3:00:00.000+9")
      # There is a trick here which is that we end up with a date in the past, so the invoice date shows as a date of today (when the invoice is generated), but the
      # subscription start dates, and invoice items correctly show the date in the past
      test_scenario_fixed_price('2013-08-02T18:00:00.000Z', 'Asia/Tokyo', '2013-08-02', '2013-08-03', '2013-08-02', '2013-09-01')
    end

    private

    def test_scenario_fixed_price(test_init_clock, account_time_zone, requested_date, expected_invoice_date, expected_subscription_date, invoice_item_end_date=nil)
      test_scenario_fixed_price_with_future_invoice(test_init_clock, account_time_zone, requested_date, expected_invoice_date, expected_subscription_date, invoice_item_end_date, nil)
    end

    def test_scenario_fixed_price_with_future_invoice(test_init_clock, account_time_zone, requested_date, expected_invoice_date, expected_subscription_date, invoice_item_end_date, days_before_next_invoice)
      setup_base(method_name, DEFAULT_MULTI_TENANT_INFO, test_init_clock)

      @account = setup_account(account_time_zone)

      bp = create_entitlement_base_with_date(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', requested_date, @user, @options)

      if days_before_next_invoice
        kb_clock_add_days(days_before_next_invoice, nil, @options)
        bp = get_subscription(bp.subscription_id, @options)
      end
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', expected_subscription_date, nil, expected_subscription_date, nil, account_time_zone)

      all_invoices = @account.invoices(@options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 0, 'USD', expected_invoice_date)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', expected_subscription_date, invoice_item_end_date)
    end

    def setup_account(time_zone)
      data = {}
      data[:time_zone] = time_zone
      account = create_account_with_data(@user, data, @options)
      add_payment_method(account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      account
    end
  end
end
