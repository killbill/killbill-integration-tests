$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestInvoicePayment < Base

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

    def test_external_payment_with_no_specified_amount
      create_charge(@account.account_id, "5.0", 'USD', 'My first charge', @user, @options)
      pay_all_unpaid_invoices(@account.account_id, true, nil, @user, @options)

      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, refreshed_account.account_balance)
      assert_equal(0, refreshed_account.account_cba)
    end

    def test_external_payment_with_exact_amount
      create_charge(@account.account_id, "7.0", 'USD', 'My first charge', @user, @options)
      create_charge(@account.account_id, "5.0", 'USD', 'My second charge', @user, @options)

      pay_all_unpaid_invoices(@account.account_id, true, "12.0", @user, @options)

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
      pay_all_unpaid_invoices(@account.account_id, false, nil, @user, @options)

      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, refreshed_account.account_balance)
      assert_equal(0, refreshed_account.account_cba)
    end

    def test_payment_with_exact_amount
      create_charge(@account.account_id, "7.0", 'USD', 'My first charge', @user, @options)
      create_charge(@account.account_id, "5.0", 'USD', 'My second charge', @user, @options)

      pay_all_unpaid_invoices(@account.account_id, false, "12.0", @user, @options)

      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, refreshed_account.account_balance)
      assert_equal(0, refreshed_account.account_cba)
    end

    def test_payment_with_lower_amount
      charge1 = create_charge(@account.account_id, "7.0", 'USD', 'My first charge', @user, @options)
      charge2 = create_charge(@account.account_id, "5.0", 'USD', 'My second charge', @user, @options)

      pay_all_unpaid_invoices(@account.account_id, false, "10.0", @user, @options)

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

      pay_all_unpaid_invoices(@account.account_id, false, "15.0", @user, @options)

      invoice1 = get_invoice_by_id(charge1.invoice_id, @options)
      assert_equal(0.0, invoice1.balance)

      invoice2 = get_invoice_by_id(charge2.invoice_id, @options)
      assert_equal(0.0, invoice2.balance)

      refreshed_account = get_account(@account.account_id, true, true, @options)
      assert_equal(0.0, refreshed_account.account_balance)
      assert_equal(0.0, refreshed_account.account_cba)
    end

  end
end
