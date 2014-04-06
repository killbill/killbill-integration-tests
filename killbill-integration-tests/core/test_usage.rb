$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestUsage < Base

    def setup
      @user = "Usage"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
    end

    def teardown
      teardown_base
    end

    # Simple case for consumable in arrear use case
    def test_simple_consumable_in_arrear

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Create Add-on
      ao_entitlement = create_entitlement_ao(bp.bundle_id, 'Gas', 'NO_BILLING_PERIOD', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'Gas', 'ADD_ON', 'NO_BILLING_PERIOD', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      start_time  = '2013-08-12T06:00:20.000Z'
      end_time  = '2013-08-17T06:00:20.000Z'

      record_usage(ao_entitlement.subscription_id, 'gallons', start_time, end_time, "10.00", @user, @options)

      kb_clock_add_days(31, nil, @options)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 539.50, 'USD', '2013-09-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 39.50, 'USD', 'USAGE', 'gas-monthly', 'gas-monthly-evergreen', '2013-08-01', '2013-08-31')


    end
  end
end
