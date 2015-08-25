$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestRefundCredit < Base

    def setup
      setup_base

      @account          = create_account(@user, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)
    end

    def teardown
      teardown_base
    end

    def test_early_cancellation_and_refund

      #
      # Create a subscription
      #
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      # Wait for first $0 trial invoice to be generated
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      #
      # Move out of trial to generate the first non $0 recurring invoice (period '2013-08-31' -> '2013-09-30')
      #
      kb_clock_add_days(30, nil, @options)
      # Wait for second invoice to be generated
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      #
      # Move the clock 10 days ahead ('2013-09-10') and cancel the subscription
      #
      kb_clock_add_days(10, nil, @options)
      bp.cancel(@user, nil, nil, '2013-09-10', nil, nil, true, @options)
      # Wait for new invoice where we see the pro-ration credit
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      # Verify we see the new credit item for the pro-rated period  '2013-09-10' -> '2013-09-30'
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, -333.33, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-10', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 333.33, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')

      payments = get_payments_for_account(@account.account_id, @options)
      assert_equal(1, payments.size)
      payment_for_second_invoice = payments[0]

      #
      # Issue a refund
      #
      refund = create_refund_adj(payment_for_second_invoice.payment_id, 333.33, nil, @user, @options)
      assert_equal(refund.transactions.size, 2)
      assert_equal(refund.transactions[1].amount, 333.33)
      assert_equal(refund.transactions[1].transaction_type, 'REFUND')

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      updated_second_invoice = all_invoices[1]
      check_invoice_item(updated_second_invoice.items[0], updated_second_invoice.invoice_id, 500, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      #
      # As expected we see a new negative credit item (showing that we consumed the previously allocated credit) because the refund with NO ADJUSTMENT
      # brought the invoice balance to a positive level and so the system used the existing credit on the account
      #
      check_invoice_item(updated_second_invoice.items[1], updated_second_invoice.invoice_id, -333.33, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')
      assert_equal(updated_second_invoice.balance, 0)

      # Verify the account balance is 0 and there is NO credit available on the account
      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(refreshed_account.account_balance, 0.0)
      assert_equal(refreshed_account.account_cba, 0.0)

    end

  end
end
