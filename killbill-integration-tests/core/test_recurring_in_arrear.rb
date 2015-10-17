$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestRecurringInArrear < Base

    def setup
      setup_base
      upload_catalog('newspaper.xml', false, @user, @options)
      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)
    end

    def teardown
      teardown_base
    end

    def test_basic_recurring

      bp = create_entitlement_base(@account.account_id, 'WeekDays', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'WeekDays', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      all_invoices = @account.invoices(true, @options)
      assert_equal(0, all_invoices.size)

      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 10.0, 'USD', '2013-09-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 10.0, 'USD', 'RECURRING', 'weekdays-monthly', 'weekdays-monthly-evergreen', '2013-08-01', '2013-09-01')

      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 10.0, 'USD', '2013-10-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 10.0, 'USD', 'RECURRING', 'weekdays-monthly', 'weekdays-monthly-evergreen', '2013-09-01', '2013-10-01')


      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 10.0, 'USD', '2013-11-01')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 10.0, 'USD', 'RECURRING', 'weekdays-monthly', 'weekdays-monthly-evergreen', '2013-10-01', '2013-11-01')

      # Move clock by 15 days and do an IMM cancellation
      kb_clock_add_days(15, nil, @options)

      requested_date = nil
      billing_policy = 'IMMEDIATE'
      bp.cancel(@user, nil, nil, requested_date, nil, billing_policy, nil, @options)
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(4, all_invoices.size)
      sort_invoices!(all_invoices)
      fourth_invoice = all_invoices[3]

      check_invoice_no_balance(fourth_invoice, 5.0, 'USD', '2013-11-16')
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, 5.0, 'USD', 'RECURRING', 'weekdays-monthly', 'weekdays-monthly-evergreen', '2013-11-01', '2013-11-16')

    end



    end
end
