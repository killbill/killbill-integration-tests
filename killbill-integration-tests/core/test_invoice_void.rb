$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestInvoiceVoid < Base

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

    def test_void_invoice

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 0, 'USD', DEFAULT_KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2013-08-01', nil)

      kb_clock_add_days(31, nil, @options)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 500.0, 'USD', '2013-09-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # try to void invoice, it should rise an exemption since the invoice is paid
      assert_raises(KillBillClient::API::BadRequest){ second_invoice.void(@user, nil, nil, @options) }

      # validate that the invoices did not change
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 500.0, 'USD', '2013-09-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # get payment to be refunded and then void the invoice
      payments = second_invoice.payments(false, false, 'NONE', @options)
      assert_equal(1, payments.size)
      assert_equal(second_invoice.amount, payments[0].purchased_amount)

      # refund payment
      KillBillClient::Model::InvoicePayment.refund(payments[0].payment_id, second_invoice.amount, nil, @user, nil, nil, @options)

      # check that the invoice is not paid
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      assert_equal(500.0, second_invoice.balance)

      # void invoice
      second_invoice.void(@user, nil, nil, @options)
      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)

      # verify that account balance is zero after the void
      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, refreshed_account.account_balance)
      assert_equal(0, refreshed_account.account_cba)
    end

  end

end