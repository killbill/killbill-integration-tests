$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestTax < Base

    def setup
      @user = 'Tax test plugin'
      setup_base(@user)

      # Create account
      @account = create_account(@user, nil, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)
    end

    def teardown
      teardown_base
    end

    def test_add_sales_tax
      assert_equal(0, @account.invoices(true, @options).size, 'Account should not have any invoice')

      # Create entitlement
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Verify the first invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size, "Invalid number of invoices: #{all_invoices.size}")
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 0, 'USD', DEFAULT_KB_INIT_DATE)
      assert_equal(1, first_invoice.items.size, "Invalid number of invoice items: #{first_invoice.items.size}")
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', DEFAULT_KB_INIT_DATE, nil)

      # Move clock after trial
      kb_clock_add_days(31, nil, @options)

      # Verify the second invoice
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size, "Invalid number of invoices: #{all_invoices.size}")
      second_invoice = all_invoices[1]
      # Amount should be $500 * 1.07 = $535
      check_invoice_no_balance(second_invoice, 535.0, 'USD', '2013-09-01')
      assert_equal(2, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 35.0, 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', nil)
      # Verify the tax item points to the recurring item
      assert_equal second_invoice.items[0].invoice_item_id, second_invoice.items[1].linked_invoice_item_id
    end
  end
end
