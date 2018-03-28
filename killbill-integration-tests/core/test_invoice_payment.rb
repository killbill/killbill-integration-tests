$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestInvoicePayment < Base

    def setup
      setup_base
      load_default_catalog

      @account          = create_account(@user, @options)
      @account = get_account(@account.account_id, false, false, @options)
    end

    def teardown
      teardown_base
    end

    def test_external_payment_with_exact_amount
      create_charge(@account.account_id, "7.0", 'USD', 'My first charge', @user, @options)
      create_charge(@account.account_id, "5.0", 'USD', 'My second charge', @user, @options)

      pay_all_unpaid_invoices(@account.account_id, true, "12.0", @user, @options)

      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, refreshed_account.account_balance)
      assert_equal(0, refreshed_account.account_cba)
    end

    def test_external_payment_with_no_specified_amount
      create_charge(@account.account_id, "5.0", 'USD', 'My first charge', @user, @options)
      pay_all_unpaid_invoices(@account.account_id, true, nil, @user, @options)

      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, refreshed_account.account_balance)
      assert_equal(0, refreshed_account.account_cba)
    end


    def test_external_payment_with_lower_amount
      charge1 = create_charge(@account.account_id, "7.0", 'USD', 'My first charge', @user, @options)
      charge2 = create_charge(@account.account_id, "5.0", 'USD', 'My second charge', @user, @options)

      pay_all_unpaid_invoices(@account.account_id, true, "10.0", @user, @options)

      invoice1 = get_invoice_by_id(charge1.invoice_id, @options)
      assert_equal(0, invoice1.balance)

      invoice2 = get_invoice_by_id(charge2.invoice_id, @options)
      assert_equal(2.0, invoice2.balance)

      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(2.0, refreshed_account.account_balance)
      assert_equal(0, refreshed_account.account_cba)
    end

    def test_external_payment_with_higer_amount
      charge1 = create_charge(@account.account_id, "7.0", 'USD', 'My first charge', @user, @options)
      charge2 = create_charge(@account.account_id, "5.0", 'USD', 'My second charge', @user, @options)

      pay_all_unpaid_invoices(@account.account_id, true, "15.0", @user, @options)

      invoice1 = get_invoice_by_id(charge1.invoice_id, @options)
      assert_equal(0.0, invoice1.balance)

      invoice2 = get_invoice_by_id(charge2.invoice_id, @options)
      assert_equal(0.0, invoice2.balance)

      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(-3.0, refreshed_account.account_balance)
      assert_equal(3.0, refreshed_account.account_cba)
    end

    def test_payment_with_no_specified_amount
      create_charge(@account.account_id, "5.0", 'USD', 'My first charge', @user, @options)
      pay_all_unpaid_invoices(@account.account_id, true, nil, @user, @options)

      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, refreshed_account.account_balance)
      assert_equal(0, refreshed_account.account_cba)
    end

    def test_payment_with_exact_amount
      create_charge(@account.account_id, "7.0", 'USD', 'My first charge', @user, @options)
      create_charge(@account.account_id, "5.0", 'USD', 'My second charge', @user, @options)

      pay_all_unpaid_invoices(@account.account_id, true, "12.0", @user, @options)

      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, refreshed_account.account_balance)
      assert_equal(0, refreshed_account.account_cba)
    end

    def test_payment_with_lower_amount
      charge1 = create_charge(@account.account_id, "7.0", 'USD', 'My first charge', @user, @options)
      charge2 = create_charge(@account.account_id, "5.0", 'USD', 'My second charge', @user, @options)

      pay_all_unpaid_invoices(@account.account_id, true, "10.0", @user, @options)

      invoice1 = get_invoice_by_id(charge1.invoice_id, @options)
      assert_equal(0, invoice1.balance)

      invoice2 = get_invoice_by_id(charge2.invoice_id, @options)
      assert_equal(2.0, invoice2.balance)

      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(2.0, refreshed_account.account_balance)
      assert_equal(0, refreshed_account.account_cba)
    end

    def test_payment_with_higher_amount
      charge1 = create_charge(@account.account_id, "7.0", 'USD', 'My first charge', @user, @options)
      charge2 = create_charge(@account.account_id, "5.0", 'USD', 'My second charge', @user, @options)

      pay_all_unpaid_invoices(@account.account_id, true, "15.0", @user, @options)

      invoice1 = get_invoice_by_id(charge1.invoice_id, @options)
      assert_equal(0.0, invoice1.balance)

      invoice2 = get_invoice_by_id(charge2.invoice_id, @options)
      assert_equal(0.0, invoice2.balance)

      # Addition paid amount was used to buy some credit
      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(-3.0, refreshed_account.account_balance)
      assert_equal(3.0, refreshed_account.account_cba)
    end

    def test_external_payment_with_multiple_partial_adjustments
      charge = create_charge(@account.account_id, '50.0', 'USD', 'My charge', @user, @options)

      pay_all_unpaid_invoices(@account.account_id, true, '50.0', @user, @options)

      account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, account.account_balance)
      assert_equal(0, account.account_cba)

      invoice = get_invoice_by_id(charge.invoice_id, @options)
      invoice_item_id = invoice.items.first.invoice_item_id
      assert_equal(0.0, invoice.balance)

      payment_id = account.payments(@options).first.payment_id

      refund(payment_id, '20.0', [{:invoice_item_id => invoice_item_id, :amount => '20'}], @user, @options)
      invoice = get_invoice_by_id(charge.invoice_id, @options)
      assert_equal(0.0, invoice.balance)
      assert_equal(-20.0, invoice.refund_adj)

      refund(payment_id, '30.0', [{:invoice_item_id => invoice_item_id, :amount => '30'}], @user, @options)
      invoice = get_invoice_by_id(charge.invoice_id, @options)
      assert_equal(0.0, invoice.balance)
      assert_equal(-50.0, invoice.refund_adj)
    end

    def test_get_account_invoice_payments
      # Verify if the returned list is empty
      assert(@account.invoice_payments('NONE', false, false, @options).empty?)

      # Create payments
      create_charge(@account.account_id, "7.0", 'USD', 'My first charge', @user, @options)
      create_charge(@account.account_id, "5.0", 'USD', 'My second charge', @user, @options)
      pay_all_unpaid_invoices(@account.account_id, true, "12.0", @user, @options)

      # Verify account invoice payments
      account_invoice_payments = @account.invoice_payments('NONE', false, false, @options)
      assert_equal(7.0, account_invoice_payments[0].purchased_amount)
      assert_equal(5.0, account_invoice_payments[1].purchased_amount)
    end

    def test_create_chargeback_and_chargeback_reversal

      # Create a charge to account
      create_charge(@account.account_id, '50.0', 'USD', 'My charge', @user, @options)

      # Create a payment
      pay_all_unpaid_invoices(@account.account_id, true, '50.0', @user, @options)

      account = get_account(@account.account_id, true, true, @options)
      payment_id = account.payments(@options).first.payment_id

      # Verify if a new transaction is created and if their type is PURCHASE
      account_transactions = account.payments(@options).first.transactions
      assert_equal(1, account_transactions.size)
      assert_equal('PURCHASE', account_transactions[0].transaction_type)
      assert_equal(0, get_account(@account.account_id, true, true, @options).account_balance)

      # Trigger chargerback
      chargeback = KillBillClient::Model::InvoicePayment.chargeback(payment_id, '50.0', 'USD', nil, @user, nil, nil, @options)

      # Verify if a new transaction is created and if their type is CHARGEBACK
      account_transactions = account.payments(@options).first.transactions
      assert_equal(2, account_transactions.size)
      assert_equal('CHARGEBACK', account_transactions[1].transaction_type)
      assert_equal(50, get_account(@account.account_id, true, true, @options).account_balance)
      assert_equal('SUCCESS', account_transactions[1].status)

      # Trigger chargerback reversal
      transaction_external_key = chargeback.transactions[1].transaction_external_key
      KillBillClient::Model::InvoicePayment.chargeback_reversal(payment_id, transaction_external_key, nil, @user, nil, nil, @options)

      # Verify if a new transaction is created and if their type is CHARGEBACK
      account_transactions = account.payments(@options).first.transactions
      assert_equal(3, account_transactions.size)
      assert_equal('CHARGEBACK', account_transactions[2].transaction_type)
      assert_equal(0, get_account(@account.account_id, true, true, @options).account_balance)
      assert_equal('PAYMENT_FAILURE', account_transactions[2].status)

    end

  end
end
