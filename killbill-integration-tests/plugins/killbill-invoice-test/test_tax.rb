$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestTax < Base

    def setup
      @user = 'Tax test plugin'
      setup_base(@user)

      # Create account
      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)
    end

    def teardown
      teardown_base
    end

    def test_adjust_tax_after_repair
      assert_equal(0, @account.invoices(true, @options).size, 'Account should not have any invoice')

      # Create entitlement
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Verify the first invoice
      all_invoices  = check_next_invoice_amount(1, 0, DEFAULT_KB_INIT_DATE, @account, @options, &@proc_account_invoices_nb)
      first_invoice = all_invoices[0]
      assert_equal(1, first_invoice.items.size, "Invalid number of invoice items: #{first_invoice.items.size}")
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', DEFAULT_KB_INIT_DATE, nil)

      # Move clock after trial
      kb_clock_add_days(31, nil, @options)

      # Verify the second invoice, amount should be $500 * 1.07 = $535
      all_invoices   = check_next_invoice_amount(2, 535.0, '2013-09-01', @account, @options, &@proc_account_invoices_nb)
      second_invoice = all_invoices[1]
      assert_equal(2, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 35.0, 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', nil)
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      # Verify the tax item points to the recurring item
      assert_equal second_invoice.items[0].linked_invoice_item_id, second_invoice.items[1].invoice_item_id

      kb_clock_add_days(1, nil, @options)

      # Change immediately
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, nil, 'IMMEDIATE', false, @options)
      check_entitlement(bp, 'Super', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      # Verify the second and third invoices, latest invoice amount is $903.23 + $63.23 - $466.67 - $32.67 = $467.12
      all_invoices   = check_next_invoice_amount(3, 467.12, '2013-09-02', @account, @options, &@proc_account_invoices_nb)
      # Second invoice should be untouched
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 535.0, 'USD', '2013-09-01')
      assert_equal(2, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      # Verify the new items on the third invoice
      third_invoice = all_invoices[2]
      assert_equal(4, third_invoice.items.size, "Invalid number of invoice items: #{third_invoice.items.size}")
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, -466.67, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-02', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, -32.67, 'USD', 'ITEM_ADJ', nil, nil, '2013-09-02', '2013-09-02')
      # New tax item amount is $903.23 * 0.07 = $63.23
      check_invoice_item(third_invoice.items[2], third_invoice.invoice_id, 63.23, 'USD', 'TAX', 'super-monthly', 'super-monthly-evergreen', '2013-09-02', nil)
      check_invoice_item(third_invoice.items[3], third_invoice.invoice_id, 903.23, 'USD', 'RECURRING', 'super-monthly', 'super-monthly-evergreen', '2013-09-02', '2013-09-30')
      # Verify the adjustment item points to the second invoice tax item
      assert_equal third_invoice.items[1].linked_invoice_item_id, second_invoice.items[0].invoice_item_id
      # Verify the new tax item points to the new recurring item
      assert_equal third_invoice.items[2].linked_invoice_item_id, third_invoice.items[3].invoice_item_id

      kb_clock_add_days(1, nil, @options)

      # Cancel immediately
      bp.cancel(@user, nil, nil, nil, 'IMMEDIATE', 'IMMEDIATE', nil, @options)

      # Verify the second, third and fourth invoices
      all_invoices   = check_next_invoice_amount(4, -931.94, '2013-09-03', @account, @options, &@proc_account_invoices_nb)
      # Second invoice should be untouched
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 535.0, 'USD', '2013-09-01')
      assert_equal(2, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      # Third invoice should be untouched
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 467.12, 'USD', '2013-09-02')
      assert_equal(4, third_invoice.items.size, "Invalid number of invoice items: #{third_invoice.items.size}")
      # Verify the new items on the fourth invoice
      fourth_invoice = all_invoices[3]
      assert_equal(4, fourth_invoice.items.size, "Invalid number of invoice items: #{fourth_invoice.items.size}")
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, -870.97, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-03', '2013-09-30')
      check_invoice_item(fourth_invoice.items[1], fourth_invoice.invoice_id, -60.97, 'USD', 'ITEM_ADJ', nil, nil, '2013-09-03', '2013-09-03')
      check_invoice_item(fourth_invoice.items[2], fourth_invoice.invoice_id, 60.97, 'USD', 'CBA_ADJ', nil, nil, '2013-09-03', '2013-09-03')
      check_invoice_item(fourth_invoice.items[3], fourth_invoice.invoice_id, 870.97, 'USD', 'CBA_ADJ', nil, nil, '2013-09-03', '2013-09-03')
      # Verify the adjustment item points to the third invoice tax item
      assert_equal fourth_invoice.items[1].linked_invoice_item_id, third_invoice.items[2].invoice_item_id
    end

    def test_adjust_tax_after_item_adjustment_with_cba
      invoice    = setup_test_adjust_tax_after_item_adjustment

      # Refund partially the payment and item adjust the charge
      payment_id = @account.payments(@options).first.payment_id
      refund(payment_id, '20.0', [{:invoice_item_id => invoice.items[0].invoice_item_id, :amount => '20'}], @user, @options)

      # Verify the invoice
      invoice = get_invoice_by_id(invoice.invoice_id, @options)
      assert_equal(0.0, invoice.balance)
      assert_equal(-20.0, invoice.refund_adj)
      check_invoice_no_balance(invoice, 16.05, 'USD', '2013-08-01')
      assert_equal(5, invoice.items.size, "Invalid number of invoice items: #{invoice.items.size}")
      check_invoice_item(invoice.items[0], invoice.invoice_id, 35.0, 'USD', 'EXTERNAL_CHARGE', nil, nil, '2013-08-01', nil)
      invoice.items[0].description = 'My first charge'
      check_invoice_item(invoice.items[1], invoice.invoice_id, 2.45, 'USD', 'TAX', nil, nil, '2013-08-01', nil)
      invoice.items[1].description = 'Tax item'
      check_invoice_item(invoice.items[2], invoice.invoice_id, -20, 'USD', 'ITEM_ADJ', nil, nil, '2013-08-01', '2013-08-01')
      check_invoice_item(invoice.items[3], invoice.invoice_id, -1.4, 'USD', 'ITEM_ADJ', nil, nil, '2013-08-01', '2013-08-01')
      invoice.items[3].description = 'Tax item'
      check_invoice_item(invoice.items[4], invoice.invoice_id, 1.4, 'USD', 'CBA_ADJ', nil, nil, '2013-08-01', '2013-08-01')
      # Verify the tax item points to the external charge item
      assert_equal invoice.items[0].invoice_item_id, invoice.items[1].linked_invoice_item_id
      # Verify the tax item adjustment points to the original tax item
      assert_equal invoice.items[1].invoice_item_id, invoice.items[3].linked_invoice_item_id

      @account = get_account(@account.account_id, true, true, @options)
      assert_equal(-1.4, @account.account_balance)
      assert_equal(1.4, @account.account_cba)
    end

    def test_adjust_tax_after_item_adjustment_no_cba
      invoice    = setup_test_adjust_tax_after_item_adjustment

      # Refund partially the payment and item adjust the charge and the tax item
      payment_id = @account.payments(@options).first.payment_id
      refund(payment_id, '21.4', [{:invoice_item_id => invoice.items[0].invoice_item_id, :amount => '20'},
                                  {:invoice_item_id => invoice.items[1].invoice_item_id, :amount => '1.4'}], @user, @options)

      # Verify the invoice
      invoice = get_invoice_by_id(invoice.invoice_id, @options)
      sort_invoice_items!([invoice])
      assert_equal(0.0, invoice.balance)
      assert_equal(-21.4, invoice.refund_adj)
      check_invoice_no_balance(invoice, 16.05, 'USD', '2013-08-01')
      assert_equal(4, invoice.items.size, "Invalid number of invoice items: #{invoice.items.size}")
      check_invoice_item(invoice.items[0], invoice.invoice_id, -20, 'USD', 'ITEM_ADJ', nil, nil, '2013-08-01', '2013-08-01')
      check_invoice_item(invoice.items[1], invoice.invoice_id, -1.4, 'USD', 'ITEM_ADJ', nil, nil, '2013-08-01', '2013-08-01')
      check_invoice_item(invoice.items[2], invoice.invoice_id, 2.45, 'USD', 'TAX', nil, nil, '2013-08-01', nil)
      assert_equal invoice.items[2].description, 'Tax item'
      check_invoice_item(invoice.items[3], invoice.invoice_id, 35.0, 'USD', 'EXTERNAL_CHARGE', nil, nil, '2013-08-01', nil)
      assert_equal invoice.items[3].description, 'My first charge'
      # Tax amount should be ($35-$20) * 0.07 = $1.05 which has been paid - no need to item adjust the TAX item
      # Verify the tax item points to the external charge item
      assert_equal invoice.items[3].invoice_item_id, invoice.items[2].linked_invoice_item_id
      # Verify the first item adjustment points to the charge item
      assert_equal invoice.items[3].invoice_item_id, invoice.items[0].linked_invoice_item_id
      # Verify the second item adjustment points to the tax item
      assert_equal invoice.items[2].invoice_item_id, invoice.items[1].linked_invoice_item_id

      @account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, @account.account_balance)
      assert_equal(0, @account.account_cba)
    end

    private

    def setup_test_adjust_tax_after_item_adjustment
      assert_equal(0, @account.invoices(true, @options).size, 'Account should not have any invoice')

      # Create external charge
      charge       = create_charge(@account.account_id, '35.0', 'USD', 'My first charge', @user, @options)

      # Verify the invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size, "Invalid number of invoices: #{all_invoices.size}")
      invoice = all_invoices[0]

      # Amount should be $35 * 1.07 = $37.45
      check_invoice_no_balance(invoice, 37.45, 'USD', '2013-08-01')
      assert_equal(2, invoice.items.size, "Invalid number of invoice items: #{invoice.items.size}")
      check_invoice_item(invoice.items[0], invoice.invoice_id, 35.0, 'USD', 'EXTERNAL_CHARGE', nil, nil, '2013-08-01', nil)
      invoice.items[0].description = 'My first charge'
      check_invoice_item(invoice.items[1], invoice.invoice_id, 2.45, 'USD', 'TAX', nil, nil, '2013-08-01', nil)
      invoice.items[1].description = 'Tax item'
      # Verify the tax item points to the external charge item
      assert_equal invoice.items[0].invoice_item_id, invoice.items[1].linked_invoice_item_id

      # Pay the invoice
      pay_all_unpaid_invoices(@account.account_id, true, invoice.balance, @user, @options)
      @account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, @account.account_balance)
      assert_equal(0, @account.account_cba)

      invoice
    end
  end
end
