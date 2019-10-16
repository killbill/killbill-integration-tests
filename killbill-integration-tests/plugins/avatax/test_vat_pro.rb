$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)
$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'plugin_base'

module KillBillIntegrationTests

  class TestVatPro < KillBillIntegrationTests::PluginBase

    PLUGIN_KEY = "dev:vat-pro"
    PLUGIN_NAME = "killbill-vat-pro-plugin"
    # Default to latest
    PLUGIN_VERSION = nil


    # Configure plugin yo create a 10% TAX items
    PLUGIN_CONFIGURATION = 'com.killbill.billing.plugin.vat.percentage=10.0'

    def setup

      @user = 'Vat pro test plugin'

      # Don't put a date too far back in the past - AvaTax won't tax it otherwise


      # TODO assume plugin is already running

      setup_base
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

    end

    def teardown
      #TODO assume plugin is already running and we leave it running
      #teardown_plugin_base(PLUGIN_KEY)
    end

    def test_simple_recurring
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(@options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 0, 'USD', DEFAULT_KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2013-08-01', nil)

      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(@options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 550.0, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 50.0, 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

    end


    def test_simple_recurring_with_adj
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(@options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 0, 'USD', DEFAULT_KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2013-08-01', nil)

      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(@options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 550.0, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 50.0, 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # 2013-09-01
      kb_clock_add_days(1, nil, @options)

      adjust_invoice_item(@account.account_id, second_invoice.invoice_id, second_invoice.items[0].invoice_item_id, 10.0, 'USD', 'Adj', @user, @options)


      all_invoices = @account.invoices(@options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 539.0, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 50.0, 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[2], second_invoice.invoice_id, -10.0, 'USD', 'ITEM_ADJ', nil, nil, '2013-09-01', '2013-09-01')
      check_invoice_item(second_invoice.items[3], second_invoice.invoice_id, -1.0, 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-01', '2013-09-01')

    end



    def test_simple_recurring_with_repair
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(@options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 0, 'USD', DEFAULT_KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2013-08-01', nil)

      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(@options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 550.0, 'USD', '2013-08-31')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 50.0, 'USD', 'TAX', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # 2013-09-10
      kb_clock_add_days(10, nil, @options)

      requested_date = nil
      entitlement_policy = "IMMEDIATE"
      billing_policy = "IMMEDIATE"
      use_requested_date_for_billing = nil
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(@options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, -366.66, 'USD', '2013-09-10')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, -333.33, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-10', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, -33.33, 'USD', 'TAX', nil, nil, '2013-09-10', '2013-09-30')

    end

  end
end
