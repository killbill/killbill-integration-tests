$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestMixedCatalog < Base

    def setup
      setup_base
      upload_catalog('Catalog-Mixed.xml', false, @user, @options)
      @account  = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    def test_with_in_advance_plan
      bp = create_entitlement_from_plan(@account.account_id, nil, 'basic-monthly-in-advance', @user, @options)
      assert_equal('basic-monthly-in-advance', bp.plan_name)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 1000.00, 'USD', DEFAULT_KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly-in-advance', 'basic-monthly-in-advance-evergreen', '2013-08-01', '2013-09-01')
    end

    def test_with_in_arrear_plan
      bp = create_entitlement_from_plan(@account.account_id, nil, 'basic-monthly-in-arrear', @user, @options)
      assert_equal('basic-monthly-in-arrear', bp.plan_name)

      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 500.00, 'USD', '2013-09-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'basic-monthly-in-arrear', 'basic-monthly-in-arrear-evergreen', '2013-08-01', '2013-09-01')
    end


    def test_mixed_mode
      bp = create_entitlement_from_plan(@account.account_id, nil, 'basic-monthly-in-advance', @user, @options)
      assert_equal('basic-monthly-in-advance', bp.plan_name)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 1000.00, 'USD', DEFAULT_KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly-in-advance', 'basic-monthly-in-advance-evergreen', '2013-08-01', '2013-09-01')

      # 2013-08-16
      kb_clock_add_days(15, nil, @options)
      requested_date = nil
      billing_policy = "IMMEDIATE"


        # Move from a plan that was billed in advance to a plan that is now billed in arrear
      bp = bp.change_plan({:planName => 'basic-monthly-in-arrear'}, @user, nil, nil, requested_date, billing_policy, nil, false, @options)
      changed_bp = get_subscription(bp.subscription_id, @options)
      assert_equal('basic-monthly-in-arrear', changed_bp.plan_name)

      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 1000, 'USD', DEFAULT_KB_INIT_DATE)
      first_invoice.items.sort! { |a, b| a.item_type <=> b.item_type }
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, -516.13, 'USD', 'CBA_ADJ', nil, nil, '2013-08-16', '2013-08-16')
      check_invoice_item(first_invoice.items[1], first_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly-in-advance', 'basic-monthly-in-advance-evergreen', '2013-08-01', '2013-09-01')

      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, -516.13, 'USD', '2013-08-16')
      second_invoice.items.sort! { |a, b| a.item_type <=> b.item_type }
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 516.13, 'USD', 'CBA_ADJ', nil, nil, '2013-08-16', '2013-08-16')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -516.13, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-16', '2013-09-01')


      # 2013-09-01
      kb_clock_add_days(16, nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 258.06, 'USD', '2013-09-01')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 258.06, 'USD', 'RECURRING', 'basic-monthly-in-arrear', 'basic-monthly-in-arrear-evergreen', '2013-08-16', '2013-09-01')


    end


  end

end
