$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestInvoice < Base

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

    def test_fixed_and_recurrring_items

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
    end

    def test_dry_run_create_bp_and_phase

      dry_run_invoice = create_subscription_dry_run(@account.account_id, nil, nil, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', @options)
      check_invoice_item(dry_run_invoice.items[0], dry_run_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2013-08-01', nil)


      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 0, 'USD', DEFAULT_KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2013-08-01', nil)


      # Move clock to switch to next phase and generate another invoice
      # Let the system compute the targetDate
      dry_run_invoice = trigger_invoice_dry_run(@account.account_id, nil, true, @options)
      check_invoice_item(dry_run_invoice.items[0], dry_run_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      kb_clock_add_days(31, nil, @options)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 500.0, 'USD', '2013-09-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
    end

    def test_dry_run_create_ao
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)

      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      dry_run_invoice = create_subscription_dry_run(@account.account_id, bp.bundle_id, nil, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', @options)
      check_invoice_item(dry_run_invoice.items[0], dry_run_invoice.invoice_id, 3.87, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-discount', '2013-08-01', '2013-08-31')


      create_entitlement_ao(@account.account_id, bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 3.87, 'USD', '2013-08-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 3.87, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-discount', '2013-08-01', '2013-08-31')
    end

    def test_dry_run_change_bp_with_multiple_policies

      bp = create_entitlement_base(@account.account_id, 'Super', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Super', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      kb_clock_add_days(30, nil, @options) # 31/08/2013
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # First dry run chg in the future by using default policy EOT as configured in the catalog
      requested_date = nil
      billing_policy = nil
      dry_run_invoice = change_plan_dry_run(@account.account_id, bp.bundle_id, bp.subscription_id, nil, 'Sports', 'BASE', 'MONTHLY', nil,
                                            requested_date, billing_policy, @options)
      assert_nil(dry_run_invoice)

      # Second overwrite policy to be IMMEDIATE
      requested_date = nil
      billing_policy = 'IMMEDIATE'
      dry_run_invoice = change_plan_dry_run(@account.account_id, bp.bundle_id, bp.subscription_id, nil, 'Sports', 'BASE', 'MONTHLY', nil,
                                            requested_date, billing_policy, @options)

      check_invoice_item(get_specific_invoice_item(dry_run_invoice.items, 'RECURRING', 'sports-monthly-evergreen'), dry_run_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(dry_run_invoice.items, 'REPAIR_ADJ', -1000.00), dry_run_invoice.invoice_id, -1000.00, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-31', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(dry_run_invoice.items, 'CBA_ADJ', 500.00), dry_run_invoice.invoice_id, 500.00, 'USD', 'CBA_ADJ', nil, nil, '2013-08-31', '2013-08-31')

      bp = bp.change_plan({:productName => 'Sports', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, nil, false, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]

      check_invoice_item(get_specific_invoice_item(third_invoice.items, 'RECURRING', 'sports-monthly-evergreen'), third_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(third_invoice.items, 'REPAIR_ADJ', -1000.00), third_invoice.invoice_id, -1000.00, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-31', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(third_invoice.items, 'CBA_ADJ', 500.00), third_invoice.invoice_id, 500.00, 'USD', 'CBA_ADJ', nil, nil, '2013-08-31', '2013-08-31')
    end

    def test_dry_run_cancel_bp_with_multiple_policies

      bp = create_entitlement_base(@account.account_id, 'Super', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Super', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      kb_clock_add_days(30, nil, @options) # 31/08/2013
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)


      # First dry run cancel in the future by using default policy EOT as configured in the catalog
      requested_date = nil
      billing_policy = nil
      dry_run_invoice = cancel_subscription_dry_run(@account.account_id, bp.bundle_id, bp.subscription_id, nil,
                                                    requested_date, billing_policy, @options)
      assert_nil(dry_run_invoice)

      # Second overwrite policy to be IMMEDIATE
      requested_date = nil
      billing_policy = 'IMMEDIATE'
      dry_run_invoice = cancel_subscription_dry_run(@account.account_id, bp.bundle_id, bp.subscription_id, nil,
                                                    requested_date, billing_policy, @options)

      check_invoice_item(get_specific_invoice_item(dry_run_invoice.items, 'REPAIR_ADJ', -1000.00), dry_run_invoice.invoice_id, -1000.00, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-31', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(dry_run_invoice.items, 'CBA_ADJ', 1000.00), dry_run_invoice.invoice_id, 1000.00, 'USD', 'CBA_ADJ', nil, nil, '2013-08-31', '2013-08-31')

      bp.cancel(@user, nil, nil, requested_date, nil, billing_policy, nil, @options)

      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]

      check_invoice_item(get_specific_invoice_item(third_invoice.items, 'REPAIR_ADJ', -1000.00), third_invoice.invoice_id, -1000.00, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-31', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(third_invoice.items, 'CBA_ADJ', 1000.00), third_invoice.invoice_id, 1000.00, 'USD', 'CBA_ADJ', nil, nil, '2013-08-31', '2013-08-31')
    end

    def test_change_bp_with_ao

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      create_entitlement_ao(@account.account_id, bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Invoice bp 2013-08-31 -> 2013-09-30, and AO with monthly DISCOUNT and BUNDLE aligned from  2013-08-31 -> 2013-09-01
      kb_clock_add_days(30, nil, @options) # 31/08/2013
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      # Add a few days before change takes place to trigger a partial repair
      # Invoice AO with monthly EVERGREEN and BUNDLE aligned from 2013-09-01 -> 2013-09-30
      kb_clock_add_days(1, nil, @options) # 01/09/2013
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)

      # Invoice bp 2013--31 -> 2013-09-30,
      kb_clock_add_days(4, nil, @options) # 05/09/2013

      requested_date = '2013-09-05'
      billing_policy = nil
      dry_run_invoice = change_plan_dry_run(@account.account_id, bp.bundle_id, bp.subscription_id, nil, 'Super', 'BASE', 'MONTHLY', nil,
                                            requested_date, billing_policy, @options)

      check_invoice_item(get_specific_invoice_item(dry_run_invoice.items, 'RECURRING', 'super-monthly-evergreen'), dry_run_invoice.invoice_id, 806.45, 'USD', 'RECURRING', 'super-monthly', 'super-monthly-evergreen', '2013-09-05', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(dry_run_invoice.items, 'REPAIR_ADJ', -416.67), dry_run_invoice.invoice_id, -416.67, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(dry_run_invoice.items, 'REPAIR_ADJ', -6.41), dry_run_invoice.invoice_id, -6.41, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')

      #
      # It looks like when we do the real call when end up with either a fifth or a sixth invoice, so in a way dryRun call is more predictable than real call. LOL...
      #
      # System is configured to have only one bus thread thread and process events one by one, so i am unclear why this is happening; should be investigated.
      #
      # While it is annoying for testing this has no real impact on end-user:
      # 1. In one case whe get one invoice with 2 REPAIR_ADJ of  -416.67 and  -6.41
      # 2. In the other case whe get a first invoice for the adjustment on the ADD_ON  REPAIR_ADJ -6.41, CBA_ADJ +6.41 and a second invoice with REPAIR_ADJ of  -416.67 and CBA_ADJ  -6.41

      #bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, nil, false, @options)
      #wait_for_expected_clause(5, @account, @options, &@proc_account_invoices_nb)
      #all_invoices = @account.invoices(true, @options)
      #sort_invoices!(all_invoices)
      #assert_equal(5, all_invoices.size)
      #fifth_invoice = all_invoices[4]

      #check_invoice_item(get_specific_invoice_item(fifth_invoice.items, 'RECURRING', 'super-monthly-evergreen'), fifth_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'super-monthly', 'super-monthly-evergreen', '2013-09-05', '2013-09-30')
      #check_invoice_item(get_specific_invoice_item(fifth_invoice.items, 'REPAIR_ADJ', -416.67), fifth_invoice.invoice_id, -416.67, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      #check_invoice_item(get_specific_invoice_item(fifth_invoice.items, 'REPAIR_ADJ', -6.41), fifth_invoice.invoice_id, -6.41, 'USD', 'CBA_ADJ', nil, nil, '2013-09-05', '2013-09-30')
    end


    def test_cancel_bp_with_ao

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      create_entitlement_ao(@account.account_id, bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Invoice bp 2013-08-31 -> 2013-09-30, and AO with monthly DISCOUNT and BUNDLE aligned from  2013-08-31 -> 2013-09-01
      kb_clock_add_days(30, nil, @options) # 31/08/2013
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      # Add a few days before change takes place to trigger a partial repair
      # Invoice AO with monthly EVERGREEN and BUNDLE aligned from 2013-09-01 -> 2013-09-30
      kb_clock_add_days(1, nil, @options) # 01/09/2013
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)

      kb_clock_add_days(4, nil, @options) # 05/09/2013

      requested_date = nil
      billing_policy = 'IMMEDIATE'
      dry_run_invoice = cancel_subscription_dry_run(@account.account_id, bp.bundle_id, bp.subscription_id, nil, requested_date, billing_policy, @options)

      check_invoice_item(get_specific_invoice_item(dry_run_invoice.items, 'CBA_ADJ', 423.08), dry_run_invoice.invoice_id, 423.08, 'USD', 'CBA_ADJ', nil, nil, '2013-09-05', '2013-09-05')
      check_invoice_item(get_specific_invoice_item(dry_run_invoice.items, 'REPAIR_ADJ', -416.67), dry_run_invoice.invoice_id, -416.67, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(dry_run_invoice.items, 'REPAIR_ADJ', -6.41), dry_run_invoice.invoice_id, -6.41, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')

    end

    def test_create_a_migration_invoice

      test_account = create_account(@user, @options)

      # Create invoices
      invoice = create_charge(test_account.account_id, '50.0', 'USD', 'First Invoice', @user, @options)

      # Create a list of invoices
      invoices = [invoice]

      # Verify if account hasn't have migration invoices
      migration_invoices = @account.migration_invoices(true, @options)
      assert_equal(0, migration_invoices.size)

      # Verify if response is success
      assert(KillBillClient::Model::Invoice.create_migration_invoice(@account.account_id, invoices, '2018-03-15', @user, nil, nil, @options).response.kind_of? Net::HTTPSuccess)

      # Verify if account has have migration invoices
      migration_invoices = @account.migration_invoices(true, @options)
      assert_equal(1, migration_invoices.size)

    end

  end
end
