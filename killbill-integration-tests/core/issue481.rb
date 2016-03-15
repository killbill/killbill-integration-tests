$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestIssue481 < Base

    def setup

      setup_base('TestIssue481', DEFAULT_MULTI_TENANT_INFO, "2016-01-01T01:00:00.000Z")

      upload_catalog('Issue481/Issue481-1.xml', false, @user, @options)
      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    def test_basic

      # 2016-01-01
      bp = create_entitlement_base(@account.account_id, 'Something', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(1, all_invoices.size)
      invoice = all_invoices[0]
      check_invoice_no_balance(invoice, 10.0, 'USD', '2016-01-01')
      check_invoice_item(invoice.items[0], invoice.invoice_id, 10.0, 'USD', 'RECURRING', 'something-monthly', 'something-monthly-evergreen', '2016-01-01', '2016-02-01')


      # Effective date of the second catalog is 2016-02-01
      upload_catalog('Issue481/Issue481-2.xml', false, @user, @options)

      # 2016-02-01
      # we still expect the original price because we did not reach 'effectiveDateForExistingSubscriptons' for Issue481-2.xml
      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      invoice = all_invoices[1]
      check_invoice_no_balance(invoice, 10.0, 'USD', '2016-02-01')
      check_invoice_item(invoice.items[0], invoice.invoice_id, 10.0, 'USD', 'RECURRING', 'something-monthly', 'something-monthly-evergreen', '2016-02-01', '2016-03-01')

      # Effective date of the third catalog is 2016-03-01
      upload_catalog('Issue481/Issue481-3.xml', false, @user, @options)

      # 2016-03-01
      # We now expect to see new price for Issue481-2.xml
      kb_clock_add_months(1,  nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      invoice = all_invoices[2]
      check_invoice_no_balance(invoice, 20.0, 'USD', '2016-03-01')
      check_invoice_item(invoice.items[0], invoice.invoice_id, 20.0, 'USD', 'RECURRING', 'something-monthly', 'something-monthly-evergreen', '2016-03-01', '2016-04-01')

      # 2016-04-01
      # We now expect to see new price for Issue481-3.xml
      kb_clock_add_months(1,  nil, @options)
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)


      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(4, all_invoices.size)
      invoice = all_invoices[3]
      check_invoice_no_balance(invoice, 40.0, 'USD', '2016-04-01')
      check_invoice_item(invoice.items[0], invoice.invoice_id, 40.0, 'USD', 'RECURRING', 'something-monthly', 'something-monthly-evergreen', '2016-04-01', '2016-05-01')

    end

  end
end
