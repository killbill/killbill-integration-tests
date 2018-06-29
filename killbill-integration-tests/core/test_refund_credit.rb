$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestRefundCredit < Base

    def setup
      setup_base
      load_default_catalog

      @account          = create_account(@user, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)
    end

    def teardown
      teardown_base
    end

    #
    # In the first scenario, we first cancel a subscription (before EOT), which results in a pro-ration credit.
    # Later we refund the payment (NO ADJUSTMENT) and check that the available credit previously applied disappears.
    #
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
      refund = refund(payment_for_second_invoice.payment_id, 333.33, nil, @user, @options)
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


    #
    # In the second scenario, we first issue the refund and then cancel the subscription (before EOT). We end up with the exact same invoice
    # as we got in the first scenario (we just reverted the order of operations but the end result is the same)
    #
    def test_refund_and_cancel

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
      # Move the clock 10 days ahead ('2013-09-10') (arbitrary, but similar to scenario one)
      #
      kb_clock_add_days(10, nil, @options)

      payments = get_payments_for_account(@account.account_id, @options)
      assert_equal(1, payments.size)
      payment_for_second_invoice = payments[0]

      #
      # Issue a refund
      #
      refund = refund(payment_for_second_invoice.payment_id, 333.33, nil, @user, @options)
      assert_equal(refund.transactions.size, 2)
      assert_equal(refund.transactions[1].amount, 333.33)
      assert_equal(refund.transactions[1].transaction_type, 'REFUND')

      #
      # Now cancel the subscription
      #
      bp.cancel(@user, nil, nil, '2013-09-10', nil, nil, true, @options)
      # Wait for new invoice where we see the pro-ration credit
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      # Verify we see the new credit item for the pro-rated period  '2013-09-10' -> '2013-09-30'
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)

      second_invoice = all_invoices[1]
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -333.33, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')

      third_invoice = all_invoices[2]
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, -333.33, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-10', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 333.33, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')


      # Verify the account balance is 0 and there is NO credit available on the account
      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(refreshed_account.account_balance, 0.0)
      assert_equal(refreshed_account.account_cba, 0.0)
    end

    #
    #
    # The third scenario is similar scenario to the first one, but this time we issue a refund with INVOICE ITEM ADJUSTMENT.
    # We end up with an account credit
    #
    def test_early_cancellation_and_refund_with_item_adjustments

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

      second_invoice = all_invoices[1]

      #
      # Issue a refund with invoice item adjustments
      # The refund will fail because the subscription has already been repaired and there is only (500 - 333.222 = 166.67) left
      #
      begin
        adjustments = [ {:invoice_item_id => second_invoice.items[0].invoice_item_id, :amount => 333.33}]
        refund(payment_for_second_invoice.payment_id, 333.33, adjustments, @user, @options)
        raise MiniTest::Assertion, "Unexpected success on refund"
      rescue KillBillClient::API::BadRequest
      end

      # However if we do a 333.33 refund with a 166.67 adjustment that should pass
      adjustments = [ {:invoice_item_id => second_invoice.items[0].invoice_item_id, :amount => 166.67}]
      refund = refund(payment_for_second_invoice.payment_id, 333.33, adjustments, @user, @options)
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
      check_invoice_item(updated_second_invoice.items[1], updated_second_invoice.invoice_id, -166.67, 'USD', 'ITEM_ADJ', nil, nil, '2013-09-10', '2013-09-10')
      assert_equal(updated_second_invoice.balance, 0)

      #
      # This time we can verify that there is a credit of $333 because the credit was generated before we did the refund and the refund included an item adjustment, the existing
      # remains
      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(refreshed_account.account_balance, -166.67)
      assert_equal(refreshed_account.account_cba, 166.67)
    end

    #
    # The fourth scenario is similar to the second one with this time we issue a refund with INVOICE ITEM ADJUSTMENT.
    #
    #
    # Note that this time the available account credit is only 166.66 (instead of 333.33). This is because the invoice item adjustment
    # specifies an amount and not a service period so the invoicing code cannot know which part was adjusted and the current behavior today
    # after we perform the cancellation is to calculate the largest available amount left (500 - 333.36)
    #
    #
    def test_refund_and_cancel_with_item_adjustments

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
      # Move the clock 10 days ahead ('2013-09-10') (arbitrary, but similar to scenario one)
      #
      kb_clock_add_days(10, nil, @options)

      payments = get_payments_for_account(@account.account_id, @options)
      assert_equal(1, payments.size)
      payment_for_second_invoice = payments[0]

      #
      # Issue a refund
      #
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      adjustments = [ {:invoice_item_id => second_invoice.items[0].invoice_item_id, :amount => 333.33}]
      refund = refund(payment_for_second_invoice.payment_id, 333.33, adjustments, @user, @options)
      assert_equal(refund.transactions.size, 2)
      assert_equal(refund.transactions[1].amount, 333.33)
      assert_equal(refund.transactions[1].transaction_type, 'REFUND')

      #
      # Now cancel the subscription
      #
      bp.cancel(@user, nil, nil, '2013-09-10', nil, nil, true, @options)
      # Wait for new invoice where we see the pro-ration credit
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      # Verify we see the new credit item for the pro-rated period  '2013-09-10' -> '2013-09-30'
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)

      second_invoice = all_invoices[1]
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -333.33, 'USD', 'ITEM_ADJ', nil, nil, '2013-09-10', '2013-09-10')


      third_invoice = all_invoices[2]
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, -166.67, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-10', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 166.67, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')

      # Verify the account balance is 0 and there is NO credit available on the account
      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(refreshed_account.account_balance, -166.67)
      assert_equal(refreshed_account.account_cba, 166.67)
    end

    def test_find_credit_by_id

      @child_account = create_child_account(@account)

      # Create new credit
      credit = create_account_credit(@child_account.account_id, 12.0, 'USD', 'Child credit', @user, @options)

      # Verify if the returned list has now one element
      get_credit = KillBillClient::Model::Credit.find_by_id(credit.credit_id , @options)

      # Verify credit fields
      assert_equal(@child_account.account_id, get_credit.account_id)
      assert_equal(12.0, get_credit.credit_amount)
      assert_equal('USD', get_credit.currency)
      assert_equal('Child credit', get_credit.description)

    end

    private


    def create_child_account(parent_account, name_key=nil, is_delegated=true)
      data = {}
      data[:name] = name_key.nil? ? "#{Time.now.to_i.to_s}-#{rand(1000000).to_s}" : name_key
      data[:external_key] = data[:name]
      data[:email] = "#{data[:name]}@hotbot.com"
      data[:currency] = parent_account.currency
      data[:time_zone] = parent_account.time_zone
      data[:parent_account_id] = parent_account.account_id
      data[:is_payment_delegated_to_parent] = is_delegated
      data[:locale] = parent_account.locale

      create_account_with_data(@user, data, @options)
    end

  end
end
