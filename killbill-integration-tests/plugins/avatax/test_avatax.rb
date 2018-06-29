$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)
$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'plugin_base'

module KillBillIntegrationTests

  class TestAvaTax < KillBillIntegrationTests::PluginBase

    PLUGIN_KEY = "avatax"
    PLUGIN_NAME = "killbill-avatax"
    # Default to latest
    PLUGIN_VERSION = nil


    PLUGIN_PROPS = [{:key => 'pluginArtifactId', :value => 'avatax-plugin'},
                    {:key => 'pluginGroupId', :value => 'org.kill-bill.billing.plugin.java'},
                    {:key => 'pluginType', :value => 'java'},
    ]

    PLUGIN_CONFIGURATION = 'org.killbill.billing.plugin.avatax.url=https://development.avalara.net' + "\n" +
                           'org.killbill.billing.plugin.avatax.accountNumber=2000248957' + "\n" +
                           'org.killbill.billing.plugin.avatax.licenseKey=01BE706D7E60E2D2' + "\n" +
                           'org.killbill.billing.plugin.avatax.companyCode=DEFAULT' + "\n" +
                           'org.killbill.billing.plugin.avatax.commitDocuments=false'

    def setup

      @user = 'AvaTax test plugin'
      # Don't put a date too far back in the past - AvaTax won't tax it otherwise
      setup_plugin_base('2017-08-01', PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
      set_configuration(PLUGIN_NAME, PLUGIN_CONFIGURATION)

      # Create account
      data = {}
      data[:name] = 'Mathew Gallager'
      data[:external_key] = Time.now.to_i.to_s + "-" + rand(1000000).to_s
      data[:email] = 'mathewgallager@kb.com'
      data[:currency] = 'USD'
      data[:time_zone] = 'UTC'
      data[:address1] = '936 Wisconsin street'
      data[:address2] = nil
      data[:postal_code] = '94109'
      data[:company] = nil
      data[:city] = 'San Francisco'
      data[:state] = 'California'
      data[:country] = 'USA'
      data[:locale] = 'en_US'
      @account = create_account_with_data(@user, data, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)

      # Assumed tax rates
      @sf_county_tax = 0.0025
      @ca_state_tax = 0.06
      @sf_special_tax = 0.0225
      @cs_sf_total_tax = @sf_county_tax + @ca_state_tax + @sf_special_tax
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY)
    end

    def test_adjust_tax_after_repair
      assert_equal(0, @account.invoices(true, @options).size, 'Account should not have any invoice')

      # Create entitlement
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2017-08-01', nil)

      # Verify the first invoice
      all_invoices  = check_next_invoice_amount(1, 0, '2017-08-01', @account, @options, &@proc_account_invoices_nb)
      first_invoice = all_invoices[0]
      assert_equal(1, first_invoice.items.size, "Invalid number of invoice items: #{first_invoice.items.size}")
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2017-08-01', nil)

      # Move clock after trial
      kb_clock_add_days(31, nil, @options)
      second_invoice_charges = 500

      # Verify the second invoice, amount should be $500 * 1.085 = $542.5
      total_amount_after_taxes_second = second_invoice_charges * (1 + @cs_sf_total_tax)
      all_invoices   = check_next_invoice_amount(2, total_amount_after_taxes_second, '2017-09-01', @account, @options, &@proc_account_invoices_nb)
      second_invoice = all_invoices[1]

      assert_equal(5, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      ca_special_taxes = second_invoice.items.select { |item| item.description == 'CA SPECIAL TAX' }
      assert_not_empty(ca_special_taxes)
      ca_special_tax_amount = 0
      ca_special_taxes.each { |sp| ca_special_tax_amount += sp.amount }
      ca_special_taxes.first.amount = ca_special_tax_amount
      check_invoice_item(ca_special_taxes.first, second_invoice.invoice_id, (second_invoice_charges * @sf_special_tax).round(2), 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2017-09-01', nil)
      ca_county_taxes = second_invoice.items.select { |item| item.description == 'CA COUNTY TAX' }
      assert_not_empty(ca_county_taxes)
      check_invoice_item(ca_county_taxes.first, second_invoice.invoice_id, (second_invoice_charges * @sf_county_tax).round(2), 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2017-09-01', nil)
      ca_state_taxes = second_invoice.items.select { |item| item.description == 'CA STATE TAX' }
      assert_not_empty(ca_state_taxes)
      check_invoice_item(ca_state_taxes.first, second_invoice.invoice_id, (second_invoice_charges * @ca_state_tax).round(2), 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2017-09-01', nil)
      sport_monthly = second_invoice.items.select { |item| item.description == 'sports-monthly-evergreen' }
      assert_not_empty(sport_monthly)
      check_invoice_item(sport_monthly.first, second_invoice.invoice_id, second_invoice_charges, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2017-08-31', '2017-09-30')
      # Verify the tax items point to the recurring item
      assert_equal(sport_monthly.first.invoice_item_id, ca_special_taxes.first.linked_invoice_item_id)
      assert_equal(sport_monthly.first.invoice_item_id, ca_county_taxes.first.linked_invoice_item_id)
      assert_equal(sport_monthly.first.invoice_item_id, ca_state_taxes.first.linked_invoice_item_id)

      kb_clock_add_days(1, nil, @options)

      # Change immediately
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, nil, 'IMMEDIATE', nil, false, @options)
      check_entitlement(bp, 'Super', 'BASE', 'MONTHLY', 'DEFAULT', '2017-08-01', nil)

      # Verify the second and third invoices, latest invoice amount is -$466.67 - $4.67 - $30.33 + $9.03 + $58.71 + $903.23 = $469.30
      invoice_adjustment = -466.67
      invoice_adjustment_after_taxes = invoice_adjustment * (1 + @cs_sf_total_tax)
      third_invoice_charges = 903.23
      third_invoice_charges_after_taxes = third_invoice_charges * (1 + @cs_sf_total_tax)

      total_amount_after_taxes_third = truncate(third_invoice_charges_after_taxes + invoice_adjustment_after_taxes)

      all_invoices   = check_next_invoice_amount(3, total_amount_after_taxes_third, '2017-09-02', @account, @options, &@proc_account_invoices_nb)
      # Second invoice should be untouched
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, total_amount_after_taxes_second, 'USD', '2017-09-01')
      assert_equal(5, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      # Verify the new items on the third invoice
      third_invoice = all_invoices[2]
      assert_equal(10, third_invoice.items.size, "Invalid number of invoice items: #{third_invoice.items.size}")
      # adjustments
      repair_adjustment = third_invoice.items.select { |item| item.item_type == 'REPAIR_ADJ' }
      assert_not_empty(repair_adjustment)
      check_invoice_item(repair_adjustment.first, third_invoice.invoice_id, invoice_adjustment, 'USD', 'REPAIR_ADJ', nil, nil, '2017-09-02', '2017-09-30')
      adj_ca_special_taxes = third_invoice.items.select { |item| item.description == 'CA SPECIAL TAX' && item.plan_name == 'sports-monthly' }
      assert_not_empty(adj_ca_special_taxes)
      ca_special_tax_amount = 0
      adj_ca_special_taxes.each { |sp| ca_special_tax_amount += sp.amount }
      adj_ca_special_taxes.first.amount = ca_special_tax_amount
      check_invoice_item(adj_ca_special_taxes.first, third_invoice.invoice_id, (invoice_adjustment * @sf_special_tax).round(2), 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2017-09-02', nil)
      adj_ca_state_taxes = third_invoice.items.select { |item| item.description == 'CA STATE TAX' && item.plan_name == 'sports-monthly'}
      assert_not_empty(adj_ca_state_taxes)
      check_invoice_item(adj_ca_state_taxes.first, third_invoice.invoice_id, (invoice_adjustment * @ca_state_tax).round(2), 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2017-09-02', nil)
      adj_ca_county_taxes = third_invoice.items.select { |item| item.description == 'CA COUNTY TAX' && item.plan_name == 'sports-monthly'}
      assert_not_empty(adj_ca_county_taxes)
      check_invoice_item(adj_ca_county_taxes.first, third_invoice.invoice_id, (invoice_adjustment * @sf_county_tax).round(2), 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2017-09-02', nil)
      # charges
      ca_special_taxes = third_invoice.items.select { |item| item.description == 'CA SPECIAL TAX' && item.plan_name == 'super-monthly' }
      assert_not_empty(ca_special_taxes)
      ca_special_tax_amount = 0
      ca_special_taxes.each { |sp| ca_special_tax_amount += sp.amount }
      ca_special_taxes.first.amount = ca_special_tax_amount
      check_invoice_item(ca_special_taxes.first, third_invoice.invoice_id, (third_invoice_charges * @sf_special_tax).round(2), 'USD', 'TAX', 'super-monthly', 'super-monthly-evergreen', '2017-09-02', nil)
      ca_county_taxes = third_invoice.items.select { |item| item.description == 'CA COUNTY TAX' && item.plan_name == 'super-monthly'}
      assert_not_empty(ca_county_taxes)
      check_invoice_item(ca_county_taxes.first, third_invoice.invoice_id, (third_invoice_charges * @sf_county_tax).round(2), 'USD', 'TAX', 'super-monthly', 'super-monthly-evergreen', '2017-09-02', nil)
      ca_state_taxes = third_invoice.items.select { |item| item.description == 'CA STATE TAX' && item.plan_name == 'super-monthly'}
      assert_not_empty(ca_state_taxes)
      check_invoice_item(ca_state_taxes.first, third_invoice.invoice_id, (third_invoice_charges * @ca_state_tax).round(2), 'USD', 'TAX', 'super-monthly', 'super-monthly-evergreen', '2017-09-02', nil)
      super_monthly = third_invoice.items.select { |item| item.description == 'super-monthly-evergreen' }
      assert_not_empty(super_monthly)
      check_invoice_item(super_monthly.first, third_invoice.invoice_id, third_invoice_charges, 'USD', 'RECURRING', 'super-monthly', 'super-monthly-evergreen', '2017-09-02', '2017-09-30')
      # Verify the return tax items point to the old recurring item
      assert_equal(sport_monthly.first.invoice_item_id, repair_adjustment.first.linked_invoice_item_id)
      assert_equal(sport_monthly.first.invoice_item_id, adj_ca_special_taxes.first.linked_invoice_item_id)
      assert_equal(sport_monthly.first.invoice_item_id, adj_ca_state_taxes.first.linked_invoice_item_id)
      assert_equal(sport_monthly.first.invoice_item_id, adj_ca_county_taxes.first.linked_invoice_item_id)
      # Verify the new tax items point to the new recurring item
      assert_equal(super_monthly.first.invoice_item_id, ca_special_taxes.first.linked_invoice_item_id)
      assert_equal(super_monthly.first.invoice_item_id, ca_county_taxes.first.linked_invoice_item_id)
      assert_equal(super_monthly.first.invoice_item_id, ca_state_taxes.first.linked_invoice_item_id)

      kb_clock_add_days(1, nil, @options)

      # Cancel immediately
      bp.cancel(@user, nil, nil, nil, 'IMMEDIATE', 'IMMEDIATE', nil, @options)

      fourth_invoice_adj = -945.01
      invoice_adjustment = -870.97
      # Verify the second, third and fourth invoices
      all_invoices   = check_next_invoice_amount(4, fourth_invoice_adj, '2017-09-03', @account, @options, &@proc_account_invoices_nb)
      # Second invoice should be untouched
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, total_amount_after_taxes_second, 'USD', '2017-09-01')
      assert_equal(5, second_invoice.items.size, "Invalid number of invoice items: #{second_invoice.items.size}")
      # Third invoice should be untouched
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, total_amount_after_taxes_third, 'USD', '2017-09-02')
      assert_equal(10, third_invoice.items.size, "Invalid number of invoice items: #{third_invoice.items.size}")
      # Verify the new items on the fourth invoice
      fourth_invoice = all_invoices[3]
      assert_equal(6, fourth_invoice.items.size, "Invalid number of invoice items: #{fourth_invoice.items.size}")
      repair_adjustment = fourth_invoice.items.select { |item| item.item_type == 'REPAIR_ADJ' }
      assert_not_empty(repair_adjustment)
      check_invoice_item(repair_adjustment.first, fourth_invoice.invoice_id, invoice_adjustment, 'USD', 'REPAIR_ADJ', nil, nil, '2017-09-03', '2017-09-30')
      adj_ca_special_taxes = fourth_invoice.items.select { |item| item.description == 'CA SPECIAL TAX' }
      assert_not_empty(adj_ca_special_taxes)
      ca_special_tax_amount = 0
      adj_ca_special_taxes.each { |sp| ca_special_tax_amount += sp.amount }
      adj_ca_special_taxes.first.amount = ca_special_tax_amount
      check_invoice_item(adj_ca_special_taxes.first, fourth_invoice.invoice_id, (invoice_adjustment * @sf_special_tax).round(2), 'USD', 'TAX', 'super-monthly', 'super-monthly-evergreen', '2017-09-03', nil)
      adj_ca_state_taxes = fourth_invoice.items.select { |item| item.description == 'CA STATE TAX' }
      assert_not_empty(adj_ca_state_taxes)
      check_invoice_item(adj_ca_state_taxes.first, fourth_invoice.invoice_id, (invoice_adjustment * @ca_state_tax).round(2), 'USD', 'TAX', 'super-monthly', 'super-monthly-evergreen', '2017-09-03', nil)
      adj_ca_county_taxes = fourth_invoice.items.select { |item| item.description == 'CA COUNTY TAX' && item.plan_name == 'super-monthly'}
      assert_not_empty(adj_ca_county_taxes)
      check_invoice_item(adj_ca_county_taxes.first, fourth_invoice.invoice_id, (invoice_adjustment * @sf_county_tax).round(2), 'USD', 'TAX', 'super-monthly', 'super-monthly-evergreen', '2017-09-03', nil)
      cba_adjustment = fourth_invoice.items.select { |item| item.item_type == 'CBA_ADJ' }
      assert_not_empty(cba_adjustment)
      check_invoice_item(cba_adjustment.first, fourth_invoice.invoice_id, fourth_invoice_adj.abs, 'USD', 'CBA_ADJ', nil, nil, '2017-09-03', '2017-09-03')
      # Verify the return tax items point to the old recurring item
      assert_equal(super_monthly.first.invoice_item_id, repair_adjustment.first.linked_invoice_item_id)
      assert_equal(super_monthly.first.invoice_item_id, adj_ca_special_taxes.first.linked_invoice_item_id)
      assert_equal(super_monthly.first.invoice_item_id, adj_ca_state_taxes.first.linked_invoice_item_id)
      assert_equal(super_monthly.first.invoice_item_id, adj_ca_county_taxes.first.linked_invoice_item_id)
    end

    def test_adjust_tax_after_item_adjustment_with_cba
      charge_amount = 35.0
      total_charge_after_taxes = charge_amount * (1 + @cs_sf_total_tax)

      amount_adj = -20.0
      amount_adj_after_taxes = amount_adj * (1 + @cs_sf_total_tax)
      total_invoice_after_adjustment = total_charge_after_taxes + amount_adj_after_taxes

      invoice    = setup_test_adjust_tax_after_item_adjustment(charge_amount, total_charge_after_taxes)

      # Refund partially the payment and item adjust the charge
      payment_id = @account.payments(@options).first.payment_id
      refund(payment_id, amount_adj.abs, [{:invoice_item_id => invoice.items[0].invoice_item_id, :amount => amount_adj.abs}], @user, @options)

      # Verify the invoice
      invoice = get_invoice_by_id(invoice.invoice_id, @options)

      assert_equal(0.0, invoice.balance)
      assert_equal(amount_adj, invoice.refund_adj)
      check_invoice_no_balance(invoice, total_invoice_after_adjustment.round(2), 'USD', '2017-08-01')
      assert_equal(11, invoice.items.size, "Invalid number of invoice items: #{invoice.items.size}")

      my_first_charge = invoice.items.select { |item| item.description == 'My first charge' }
      assert_not_empty(my_first_charge)
      check_invoice_item(my_first_charge.first, invoice.invoice_id, charge_amount, 'USD', 'EXTERNAL_CHARGE', nil, nil, '2017-08-01', nil)

      ca_special_taxes = invoice.items.select { |item| item.description == 'CA SPECIAL TAX' }
      assert_not_empty(ca_special_taxes)
      ca_special_taxes = sum_items_amount(ca_special_taxes)
      expected_ca_special_tax_amount = (charge_amount * @sf_special_tax).round(2) + (amount_adj * @sf_special_tax).round(2)
      check_invoice_item(ca_special_taxes, invoice.invoice_id, expected_ca_special_tax_amount, 'USD', 'TAX', nil, nil, '2017-08-01', nil)

      ca_county_taxes = invoice.items.select { |item| item.description == 'CA COUNTY TAX' }
      assert_not_empty(ca_county_taxes)
      ca_county_taxes = sum_items_amount(ca_county_taxes)
      expected_ca_county_taxes = (charge_amount * @sf_county_tax).round(2) + (amount_adj * @sf_county_tax).round(2)
      check_invoice_item(ca_county_taxes, invoice.invoice_id, expected_ca_county_taxes, 'USD', 'TAX', nil, nil, '2017-08-01', nil)

      ca_state_taxes = invoice.items.select { |item| item.description == 'CA STATE TAX' }
      assert_not_empty(ca_state_taxes)
      ca_state_taxes = sum_items_amount(ca_state_taxes)
      expected_ca_state_taxes = (charge_amount * @ca_state_tax).round(2) + (amount_adj * @ca_state_tax).round(2)
      check_invoice_item(ca_state_taxes, invoice.invoice_id, expected_ca_state_taxes, 'USD', 'TAX', nil, nil, '2017-08-01', nil)

      item_adjustment = invoice.items.select { |item| item.item_type == 'ITEM_ADJ' }
      assert_not_empty(item_adjustment)
      check_invoice_item(item_adjustment.first, invoice.invoice_id, amount_adj, 'USD', 'ITEM_ADJ', nil, nil, '2017-08-01', '2017-08-01')
      cba_adjustment = invoice.items.select { |item| item.item_type == 'CBA_ADJ' }
      assert_not_empty(cba_adjustment)
      check_invoice_item(cba_adjustment.first, invoice.invoice_id, 1.7, 'USD', 'CBA_ADJ', nil, nil, '2017-08-01', '2017-08-01')
      # Verify the tax items point to the external charge item
      assert_equal(my_first_charge.first.invoice_item_id, ca_special_taxes.linked_invoice_item_id)
      assert_equal(my_first_charge.first.invoice_item_id, ca_county_taxes.linked_invoice_item_id)
      assert_equal(my_first_charge.first.invoice_item_id, ca_state_taxes.linked_invoice_item_id)
      assert_equal(my_first_charge.first.invoice_item_id, item_adjustment.first.linked_invoice_item_id)

      @account = get_account(@account.account_id, true, true, @options)
      assert_equal(-1.7, @account.account_balance)
      assert_equal(1.7, @account.account_cba)
    end

    private

    def setup_test_adjust_tax_after_item_adjustment(charge_amount, total_charge_after_taxes)
      assert_equal(0, @account.invoices(true, @options).size, 'Account should not have any invoice')

      # Create external charge
      create_charge(@account.account_id, charge_amount, 'USD', 'My first charge', @user, @options)

      # Verify the invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size, "Invalid number of invoices: #{all_invoices.size}")
      invoice = all_invoices[0]

      # Amount should be $35 * 1.085 = $37.98
      check_invoice_no_balance(invoice, total_charge_after_taxes.round(2), 'USD', '2017-08-01')
      assert_equal(5, invoice.items.size, "Invalid number of invoice items: #{invoice.items.size}")
      my_first_charge = invoice.items.select { |item| item.description == 'My first charge' }
      assert_not_empty(my_first_charge)
      check_invoice_item(my_first_charge.first, invoice.invoice_id, charge_amount, 'USD', 'EXTERNAL_CHARGE', nil, nil, '2017-08-01', nil)
      ca_special_taxes = invoice.items.select { |item| item.description == 'CA SPECIAL TAX' }
      assert_not_empty(ca_special_taxes)
      ca_special_tax_amount = 0
      ca_special_taxes.each { |sp| ca_special_tax_amount += sp.amount }
      ca_special_taxes.first.amount = ca_special_tax_amount
      check_invoice_item(ca_special_taxes.first, invoice.invoice_id, (charge_amount * @sf_special_tax).round(2), 'USD', 'TAX', nil, nil, '2017-08-01', nil)
      ca_county_taxes = invoice.items.select { |item| item.description == 'CA COUNTY TAX' }
      assert_not_empty(ca_county_taxes)
      check_invoice_item(ca_county_taxes.first, invoice.invoice_id, (charge_amount * @sf_county_tax).round(2), 'USD', 'TAX', nil, nil, '2017-08-01', nil)
      ca_state_taxes = invoice.items.select { |item| item.description == 'CA STATE TAX' }
      assert_not_empty(ca_state_taxes)
      check_invoice_item(ca_state_taxes.first, invoice.invoice_id, (charge_amount * @ca_state_tax).round(2), 'USD', 'TAX', nil, nil, '2017-08-01', nil)

      # Verify the tax items point to the external charge item
      assert_equal(my_first_charge.first.invoice_item_id, ca_special_taxes.first.linked_invoice_item_id)
      assert_equal(my_first_charge.first.invoice_item_id, ca_county_taxes.first.linked_invoice_item_id)
      assert_equal(my_first_charge.first.invoice_item_id, ca_state_taxes.first.linked_invoice_item_id)

      # Pay the invoice
      pay_all_unpaid_invoices(@account.account_id, false, invoice.balance, @user, @options)
      @account = get_account(@account.account_id, true, true, @options)
      assert_equal(0, @account.account_balance)
      assert_equal(0, @account.account_cba)

      invoice
    end

    def truncate(amount, places=2)
      result = (amount.abs * ('1' + '0' * places).to_i).floor / (('1' + '0' * places) + '.0').to_f
      amount < 0 ? result * -1 : result
    end

    def sum_items_amount(items)
      amount = 0
      items.each { |sp| amount += sp.amount }
      items.first.amount = amount

      items.first
    end

  end
end
