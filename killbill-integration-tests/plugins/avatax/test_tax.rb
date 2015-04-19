$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestTax < Base

    def setup
      @user = 'AvaTax test plugin'
      # Don't put a date too far back in the past - AvaTax won't tax it otherwise
      setup_base(@user, DEFAULT_MULTI_TENANT_INFO, '2014-08-01')

      # Create account
      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)

      # Assumed tax rates
      @sf_county_tax = 0.01
      @ca_state_tax = 0.065
    end

    def teardown
      teardown_base
    end

    def test_adjust_tax_after_repair
      assert_equal(0, @account.invoices(true, @options).size, 'Account should not have any invoice')

      # Create entitlement
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2014-08-01', nil)

      # Verify the first invoice
      all_invoices  = check_next_invoice_amount(1, 0, '2014-08-01', @account, @options, &@proc_account_invoices_nb)
      first_invoice = all_invoices[0]
      assert_equal(1, first_invoice.items.size, "Invalid number of invoice items: #{first_invoice.items.size}")
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2014-08-01', nil)

      # Move clock after trial
      kb_clock_add_days(31, nil, @options)

      # Verify the second invoice, amount should be $500 * 1.075 = $537.5
      all_invoices   = check_next_invoice_amount(2, 537.5, '2014-09-01', @account, @options, &@proc_account_invoices_nb)
      second_invoice = all_invoices[1]
      assert_equal(3, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 5.0, 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2014-09-01', nil)
      assert_equal('CA COUNTY TAX', second_invoice.items[0].description)
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 32.5, 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2014-09-01', nil)
      assert_equal('CA STATE TAX', second_invoice.items[1].description)
      check_invoice_item(second_invoice.items[2], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2014-08-31', '2014-09-30')
      # Verify the tax items point to the recurring item
      assert_equal(second_invoice.items[2].invoice_item_id, second_invoice.items[0].linked_invoice_item_id)
      assert_equal(second_invoice.items[2].invoice_item_id, second_invoice.items[1].linked_invoice_item_id)

      kb_clock_add_days(1, nil, @options)

      # Change immediately
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, nil, 'IMMEDIATE', false, @options)
      check_entitlement(bp, 'Super', 'BASE', 'MONTHLY', 'DEFAULT', '2014-08-01', nil)

      # Verify the second and third invoices, latest invoice amount is -$466.67 - $4.67 - $30.33 + $9.03 + $58.71 + $903.23 = $469.30
      all_invoices   = check_next_invoice_amount(3, 469.30, '2014-09-02', @account, @options, &@proc_account_invoices_nb)
      # Second invoice should be untouched
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 537.5, 'USD', '2014-09-01')
      assert_equal(3, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      # Verify the new items on the third invoice
      third_invoice = all_invoices[2]
      assert_equal(6, third_invoice.items.size, "Invalid number of invoice items: #{third_invoice.items.size}")
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, -466.67, 'USD', 'REPAIR_ADJ', nil, nil, '2014-09-02', '2014-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, -30.33, 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2014-09-02', nil)
      assert_equal('CA STATE TAX', third_invoice.items[1].description)
      check_invoice_item(third_invoice.items[2], third_invoice.invoice_id, -4.67, 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2014-09-02', nil)
      assert_equal('CA COUNTY TAX', third_invoice.items[2].description)
      check_invoice_item(third_invoice.items[3], third_invoice.invoice_id, 9.03, 'USD', 'TAX', 'super-monthly', 'super-monthly-evergreen', '2014-09-02', nil)
      assert_equal('CA COUNTY TAX', third_invoice.items[3].description)
      check_invoice_item(third_invoice.items[4], third_invoice.invoice_id, 58.71, 'USD', 'TAX', 'super-monthly', 'super-monthly-evergreen', '2014-09-02', nil)
      assert_equal('CA STATE TAX', third_invoice.items[4].description)
      check_invoice_item(third_invoice.items[5], third_invoice.invoice_id, 903.23, 'USD', 'RECURRING', 'super-monthly', 'super-monthly-evergreen', '2014-09-02', '2014-09-30')
      # Verify the return tax items point to the old recurring item
      assert_equal(second_invoice.items[2].invoice_item_id, third_invoice.items[1].linked_invoice_item_id)
      assert_equal(second_invoice.items[2].invoice_item_id, third_invoice.items[2].linked_invoice_item_id)
      # Verify the new tax items point to the new recurring item
      assert_equal(third_invoice.items[5].invoice_item_id, third_invoice.items[3].linked_invoice_item_id)
      assert_equal(third_invoice.items[5].invoice_item_id, third_invoice.items[4].linked_invoice_item_id)

      kb_clock_add_days(1, nil, @options)

      # Cancel immediately
      bp.cancel(@user, nil, nil, nil, 'IMMEDIATE', 'IMMEDIATE', nil, @options)

      # Verify the second, third and fourth invoices
      all_invoices   = check_next_invoice_amount(4, -936.29, '2014-09-03', @account, @options, &@proc_account_invoices_nb)
      # Second invoice should be untouched
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 537.5, 'USD', '2014-09-01')
      assert_equal(3, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      # Third invoice should be untouched
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 469.30, 'USD', '2014-09-02')
      assert_equal(6, third_invoice.items.size, "Invalid number of invoice items: #{third_invoice.items.size}")
      # Verify the new items on the fourth invoice
      fourth_invoice = all_invoices[3]
      assert_equal(5, fourth_invoice.items.size, "Invalid number of invoice items: #{fourth_invoice.items.size}")
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, -870.97, 'USD', 'REPAIR_ADJ', nil, nil, '2014-09-03', '2014-09-30')
      check_invoice_item(fourth_invoice.items[1], fourth_invoice.invoice_id, -56.61, 'USD', 'TAX', 'super-monthly', 'super-monthly-evergreen', '2014-09-03', nil)
      assert_equal('CA STATE TAX', fourth_invoice.items[1].description)
      check_invoice_item(fourth_invoice.items[2], fourth_invoice.invoice_id, -8.71, 'USD', 'TAX', 'super-monthly', 'super-monthly-evergreen', '2014-09-03', nil)
      assert_equal('CA COUNTY TAX', fourth_invoice.items[2].description)
      check_invoice_item(fourth_invoice.items[3], fourth_invoice.invoice_id, 65.32, 'USD', 'CBA_ADJ', nil, nil, '2014-09-03', '2014-09-03')
      check_invoice_item(fourth_invoice.items[4], fourth_invoice.invoice_id, 870.97, 'USD', 'CBA_ADJ', nil, nil, '2014-09-03', '2014-09-03')
      # Verify the return tax items point to the old recurring item
      assert_equal(third_invoice.items[5].invoice_item_id, fourth_invoice.items[1].linked_invoice_item_id)
      assert_equal(third_invoice.items[5].invoice_item_id, fourth_invoice.items[2].linked_invoice_item_id)
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
      check_invoice_no_balance(invoice, 16.13, 'USD', '2014-08-01')
      assert_equal(7, invoice.items.size, "Invalid number of invoice items: #{invoice.items.size}")
      check_invoice_item(invoice.items[0], invoice.invoice_id, 35.0, 'USD', 'EXTERNAL_CHARGE', nil, nil, '2014-08-01', nil)
      assert_equal('My first charge', invoice.items[0].description)
      check_invoice_item(invoice.items[1], invoice.invoice_id, 2.28, 'USD', 'TAX', nil, nil, '2014-08-01', nil)
      assert_equal('CA STATE TAX', invoice.items[1].description)
      check_invoice_item(invoice.items[2], invoice.invoice_id, 0.35, 'USD', 'TAX', nil, nil, '2014-08-01', nil)
      assert_equal('CA COUNTY TAX', invoice.items[2].description)
      check_invoice_item(invoice.items[3], invoice.invoice_id, -20, 'USD', 'ITEM_ADJ', nil, nil, '2014-08-01', '2014-08-01')
      check_invoice_item(invoice.items[4], invoice.invoice_id, -1.3, 'USD', 'TAX', nil, nil, '2014-08-01', nil)
      assert_equal('CA STATE TAX', invoice.items[4].description)
      check_invoice_item(invoice.items[5], invoice.invoice_id, -0.2, 'USD', 'TAX', nil, nil, '2014-08-01', nil)
      assert_equal('CA COUNTY TAX', invoice.items[5].description)
      check_invoice_item(invoice.items[6], invoice.invoice_id, 1.5, 'USD', 'CBA_ADJ', nil, nil, '2014-08-01', '2014-08-01')
      # Verify the tax items point to the external charge item
      assert_equal(invoice.items[0].invoice_item_id, invoice.items[1].linked_invoice_item_id)
      assert_equal(invoice.items[0].invoice_item_id, invoice.items[2].linked_invoice_item_id)
      assert_equal(invoice.items[0].invoice_item_id, invoice.items[4].linked_invoice_item_id)
      assert_equal(invoice.items[0].invoice_item_id, invoice.items[5].linked_invoice_item_id)

      @account = get_account(@account.account_id, true, true, @options)
      assert_equal(-1.5, @account.account_balance)
      assert_equal(1.5, @account.account_cba)
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

      # Amount should be $35 * 1.075 = $37.63
      check_invoice_no_balance(invoice, 37.63, 'USD', '2014-08-01')
      assert_equal(3, invoice.items.size, "Invalid number of invoice items: #{invoice.items.size}")
      check_invoice_item(invoice.items[0], invoice.invoice_id, 35.0, 'USD', 'EXTERNAL_CHARGE', nil, nil, '2014-08-01', nil)
      assert_equal('My first charge', invoice.items[0].description)
      check_invoice_item(invoice.items[1], invoice.invoice_id, 2.28, 'USD', 'TAX', nil, nil, '2014-08-01', nil)
      assert_equal('CA STATE TAX', invoice.items[1].description)
      check_invoice_item(invoice.items[2], invoice.invoice_id, 0.35, 'USD', 'TAX', nil, nil, '2014-08-01', nil)
      assert_equal('CA COUNTY TAX', invoice.items[2].description)
      # Verify the tax items point to the external charge item
      assert_equal(invoice.items[0].invoice_item_id, invoice.items[1].linked_invoice_item_id)
      assert_equal(invoice.items[0].invoice_item_id, invoice.items[2].linked_invoice_item_id)

      # Pay the invoice
      pay_all_unpaid_invoices(@account.account_id, true, invoice.balance, @user, @options)
      @account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, @account.account_balance)
      assert_equal(0, @account.account_cba)

      invoice
    end
  end
end
