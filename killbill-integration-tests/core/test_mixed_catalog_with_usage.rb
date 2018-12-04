$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'date'

require 'test_base'

module KillBillIntegrationTests

  class TestMixedCatalogWithUsage < Base

    def setup
      setup_base
      upload_catalog('Catalog-Mixed-With-Usage.xml', false, @user, @options)
      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    # Basic test to verify/understand the catalog
    def test_basic_recurring
      # Verify account BCD
      assert_account_bcd(0)

      bp = create_entitlement_from_plan(@account.account_id, nil, 'voip-monthly-unlimited', @user, @options)
      assert_equal('voip-monthly-unlimited', bp.plan_name)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Verify account BCD (SUBSCRIPTION alignment)
      assert_account_bcd(0)

      # First invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 39.99, 'USD', DEFAULT_KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 39.99, 'USD', 'RECURRING', 'voip-monthly-unlimited', 'voip-monthly-unlimited-evergreen', '2013-08-01', '2013-09-01')

      # 2013-09-01
      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Second invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 39.99, 'USD', '2013-09-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 39.99, 'USD', 'RECURRING', 'voip-monthly-unlimited', 'voip-monthly-unlimited-evergreen', '2013-09-01', '2013-10-01')

      # Verify END_OF_TERM cancellation
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      bp = get_subscription(bp.subscription_id, @options)
      check_subscription(bp, 'Voip', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, '2013-09-01', DEFAULT_KB_INIT_DATE, '2013-10-01')
      assert_equal('CANCELLED', bp.state)

      # 2013-10-01
      kb_clock_add_months(1, nil, @options)

      # No new invoice is generated
      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
    end

    # Basic test to verify/understand the catalog
    def test_basic_usage
      # Verify account BCD
      assert_account_bcd(0)

      bp = create_entitlement_from_plan(@account.account_id, nil, 'voip-monthly-by-usage', @user, @options)
      assert_equal('voip-monthly-by-usage', bp.plan_name)
      assert_equal(0, @account.invoices(true, @options).size)

      # Verify account BCD (SUBSCRIPTION alignment)
      assert_account_bcd(0)

      # 2013-08-01 -> 2013-08-31, record a total of 15 minutes
      (0..30).each do |day|
        today = Date.parse('2013-08-01') + day
        usage_input = [{:unit_type => 'minutes',
                        :usage_records => [{:record_date => today.to_s, :amount => day % 2}]
                       }]
        record_usage(bp.subscription_id, usage_input, @user, @options)

        # Check recorded usage (note that endDate is exclusive in the API)
        recorded_usage = get_usage_for_subscription(bp.subscription_id, '2013-08-01', (today + 1).to_s, @options)
        assert_equal(recorded_usage.subscription_id, bp.subscription_id)
        assert_equal(recorded_usage.start_date, '2013-08-01')
        assert_equal(recorded_usage.end_date, (today + 1).to_s)
        assert_equal(recorded_usage.rolled_up_units.size, 1)
        assert_equal(recorded_usage.rolled_up_units[0].amount, day - day / 2)
        assert_equal(recorded_usage.rolled_up_units[0].unit_type, 'minutes')

        # No invoice
        assert_equal(0, @account.invoices(true, @options).size)

        kb_clock_add_days(1, nil, @options)
      end

      # 2013-09-01
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # First invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 14.85, 'USD', '2013-09-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 14.85, 'USD', 'USAGE', 'voip-monthly-by-usage', 'voip-monthly-by-usage-evergreen', '2013-08-01', '2013-09-01')
      # AGGREGATE mode by default
      check_invoice_consumable_item_detail(first_invoice.items[0],
                                           [{:tier => 1, :unit_type => 'minutes', :unit_qty => 15, :tier_price => 0.99 }], 14.85)

      # 2013-10-01
      kb_clock_add_months(1, nil, @options)

      # Second invoice: verify month with no usage data
      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 0, 'USD', '2013-10-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 0, 'USD', 'USAGE', 'voip-monthly-by-usage', 'voip-monthly-by-usage-evergreen', '2013-09-01', '2013-10-01')
      # AGGREGATE mode by default
      check_invoice_consumable_item_detail(second_invoice.items[0],
                                           [{:tier => 1, :unit_type => 'minutes', :unit_qty => 0, :tier_price => 0.99 }], 0)

      # 2013-10-15
      kb_clock_add_days(14, nil, @options)

      # Add usage for the month
      usage_input = [{:unit_type => 'minutes',
                      :usage_records => [{:record_date => '2013-10-01', :amount => 1},
                                         {:record_date => '2013-10-02', :amount => 1},
                                         {:record_date => '2013-10-03', :amount => 1},
                                         {:record_date => '2013-10-04', :amount => 1},
                                         {:record_date => '2013-10-05', :amount => 1},
                                         {:record_date => '2013-10-07', :amount => 1}]
                     }]
      record_usage(bp.subscription_id, usage_input, @user, @options)

      # Verify IMMEDIATE cancellation
      requested_date = nil
      entitlement_policy = nil
      billing_policy = nil
      use_requested_date_for_billing = nil
      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      bp = get_subscription(bp.subscription_id, @options)
      check_subscription(bp, 'Voip', 'BASE', 'NO_BILLING_PERIOD', 'DEFAULT', DEFAULT_KB_INIT_DATE, '2013-10-15', DEFAULT_KB_INIT_DATE, '2013-10-15')
      assert_equal('CANCELLED', bp.state)

      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      # Third invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 5.94, 'USD', '2013-10-15')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 5.94, 'USD', 'USAGE', 'voip-monthly-by-usage', 'voip-monthly-by-usage-evergreen', '2013-10-01', '2013-10-15')
      # AGGREGATE mode by default
      check_invoice_consumable_item_detail(third_invoice.items[0],
                                           [{:tier => 1, :unit_type => 'minutes', :unit_qty => 6, :tier_price => 0.99 }], 5.94)

      # 2013-12-15
      kb_clock_add_months(2, nil, @options)

      # No new invoice is generated
      assert_equal(3, @account.invoices(true, @options).size)
    end

    # Basic test to verify/understand the catalog
    def test_pause_resume_recurring
      # Verify account BCD
      assert_account_bcd(0)

      bp = create_entitlement_from_plan(@account.account_id, nil, 'voip-monthly-unlimited', @user, @options)
      assert_equal('voip-monthly-unlimited', bp.plan_name)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Verify account BCD (SUBSCRIPTION alignment)
      assert_account_bcd(0)

      # First invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 39.99, 'USD', DEFAULT_KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 39.99, 'USD', 'RECURRING', 'voip-monthly-unlimited', 'voip-monthly-unlimited-evergreen', '2013-08-01', '2013-09-01')

      # 2013-08-05: pause entitlement now, billing at CTD (no proration)
      kb_clock_add_days(4, nil, @options)
      set_bundle_blocking_state(bp.bundle_id, 'SUSPENDED', 'BillingAdmin', false, false, true, '2013-09-01', @user, @options)
      set_bundle_blocking_state(bp.bundle_id, 'SUSPENDED', 'EntitlementAdmin', false, true, false, nil, @user, @options)

      # No new invoice
      assert_equal(1, @account.invoices(true, @options).size)

      # 2013-10-05
      kb_clock_add_months(2, nil, @options)

      # No new invoice
      assert_equal(1, @account.invoices(true, @options).size)

      # Resume entitlement now, billing at BCD (no proration)
      set_bundle_blocking_state(bp.bundle_id, 'UNSUSPENDED', 'EntitlementAdmin', false, false, false, nil, @user, @options)
      set_bundle_blocking_state(bp.bundle_id, 'UNSUSPENDED', 'BillingAdmin', false, false, false, '2013-10-01', @user, @options)

      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Second invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 39.99, 'USD', '2013-10-05')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 39.99, 'USD', 'RECURRING', 'voip-monthly-unlimited', 'voip-monthly-unlimited-evergreen', '2013-10-01', '2013-11-01')

      # 2013-11-01
      kb_clock_add_days(27, nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      # Third invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 39.99, 'USD', '2013-11-01')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 39.99, 'USD', 'RECURRING', 'voip-monthly-unlimited', 'voip-monthly-unlimited-evergreen', '2013-11-01', '2013-12-01')
    end

    # Basic test to verify/understand the catalog
    def test_pause_resume_usage
      # Verify account BCD
      assert_account_bcd(0)

      bp = create_entitlement_from_plan(@account.account_id, nil, 'voip-monthly-by-usage', @user, @options)
      assert_equal('voip-monthly-by-usage', bp.plan_name)
      assert_equal(0, @account.invoices(true, @options).size)

      # Verify account BCD (SUBSCRIPTION alignment)
      assert_account_bcd(0)

      # Add usage for the month
      usage_input = [{:unit_type => 'minutes',
                      :usage_records => [{:record_date => '2013-08-01', :amount => 1},
                                         {:record_date => '2013-08-02', :amount => 1},
                                         {:record_date => '2013-08-03', :amount => 1},
                                         {:record_date => '2013-08-04', :amount => 1},
                                         {:record_date => '2013-08-05', :amount => 1}]
                     }]
      record_usage(bp.subscription_id, usage_input, @user, @options)

      # 2013-08-05: pause entitlement now, billing at BCD
      kb_clock_add_days(4, nil, @options)
      set_bundle_blocking_state(bp.bundle_id, 'SUSPENDED', 'BillingAdmin', false, false, true, '2013-09-01', @user, @options)
      set_bundle_blocking_state(bp.bundle_id, 'SUSPENDED', 'EntitlementAdmin', false, true, false, nil, @user, @options)

      # No invoice
      assert_equal(0, @account.invoices(true, @options).size)

      # 2013-09-01
      kb_clock_add_days(27, nil, @options)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # First invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 4.95, 'USD', '2013-09-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 4.95, 'USD', 'USAGE', 'voip-monthly-by-usage', 'voip-monthly-by-usage-evergreen', '2013-08-01', '2013-09-01')
      # AGGREGATE mode by default
      check_invoice_consumable_item_detail(first_invoice.items[0],
                                           [{:tier => 1, :unit_type => 'minutes', :unit_qty => 5, :tier_price => 0.99 }], 4.95)

      # 2013-09-05: resume both entitlement and billing now
      kb_clock_add_days(4, nil, @options)
      set_bundle_blocking_state(bp.bundle_id, 'UNSUSPENDED', 'EntitlementAdmin', false, false, false, nil, @user, @options)
      set_bundle_blocking_state(bp.bundle_id, 'UNSUSPENDED', 'BillingAdmin', false, false, false, nil, @user, @options)

      # Reset the BCD
      bp.bill_cycle_day_local = 5;
      effective_from_date  = nil
      bp.update_bcd(@user, nil, nil, effective_from_date, nil, @options)

      # Second invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 0, 'USD', '2013-09-05')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 0, 'USD', 'USAGE', 'voip-monthly-by-usage', 'voip-monthly-by-usage-evergreen', '2013-09-01', '2013-09-05')
      # AGGREGATE mode by default
      check_invoice_consumable_item_detail(second_invoice.items[0],
                                           [{:tier => 1, :unit_type => 'minutes', :unit_qty => 0, :tier_price => 0.99 }], 0)

      # Add usage for the month
      usage_input = [{:unit_type => 'minutes',
                      :usage_records => [{:record_date => '2013-09-05', :amount => 1},
                                         {:record_date => '2013-09-06', :amount => 1},
                                         {:record_date => '2013-09-07', :amount => 1},
                                         {:record_date => '2013-10-01', :amount => 1},
                                         {:record_date => '2013-10-02', :amount => 1}]
                     }]
      record_usage(bp.subscription_id, usage_input, @user, @options)

      # 2013-10-05
      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      # Third invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 4.95, 'USD', '2013-10-05')
      # Verify new BCD
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 4.95, 'USD', 'USAGE', 'voip-monthly-by-usage', 'voip-monthly-by-usage-evergreen', '2013-09-05', '2013-10-05')
      # AGGREGATE mode by default
      check_invoice_consumable_item_detail(third_invoice.items[0],
                                           [{:tier => 1, :unit_type => 'minutes', :unit_qty => 5, :tier_price => 0.99 }], 4.95)
    end

    # Upgrade to the unlimited plan
    def test_change_usage_to_recurring_before_first_invoice
      # Verify account BCD
      assert_account_bcd(0)

      bp = create_entitlement_from_plan(@account.account_id, nil, 'voip-monthly-by-usage', @user, @options)
      assert_equal('voip-monthly-by-usage', bp.plan_name)
      assert_equal(0, @account.invoices(true, @options).size)

      # Verify account BCD (SUBSCRIPTION alignment)
      assert_account_bcd(0)

      # Add usage for the month
      usage_input = [{:unit_type => 'minutes',
                      :usage_records => [{:record_date => '2013-08-01', :amount => 1},
                                         {:record_date => '2013-08-02', :amount => 1},
                                         {:record_date => '2013-08-03', :amount => 1},
                                         {:record_date => '2013-08-04', :amount => 1},
                                         {:record_date => '2013-08-05', :amount => 1},
                                         {:record_date => '2013-08-07', :amount => 1}]
                     }]
      record_usage(bp.subscription_id, usage_input, @user, @options)

      # 2013-08-15
      kb_clock_add_days(14, nil, @options)
      assert_equal(0, @account.invoices(true, @options).size)

      # Reset the BCD: we want both outstanding usage and new recurring charged right away
      bp.bill_cycle_day_local = 15;
      effective_from_date  = nil
      bp.update_bcd(@user, nil, nil, effective_from_date, nil, @options)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Verify account BCD (SUBSCRIPTION alignment)
      assert_account_bcd(0)

      # First invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 5.94, 'USD', '2013-08-15')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 5.94, 'USD', 'USAGE', 'voip-monthly-by-usage', 'voip-monthly-by-usage-evergreen', '2013-08-01', '2013-08-15')
      # AGGREGATE mode by default
      check_invoice_consumable_item_detail(first_invoice.items[0],
                                           [{:tier => 1, :unit_type => 'minutes', :unit_qty => 6, :tier_price => 0.99 }], 5.94)

      # Upgrade
      requested_date = nil
      billing_policy = nil
      bp = bp.change_plan({:productName => 'Voip', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, nil, false, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      check_entitlement(bp, 'Voip', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      assert_equal('voip-monthly-unlimited', bp.plan_name)

      # Second invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 39.99, 'USD', '2013-08-15')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 39.99, 'USD', 'RECURRING', 'voip-monthly-unlimited', 'voip-monthly-unlimited-evergreen', '2013-08-15', '2013-09-15')

      # 2013-09-15
      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      # Third invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 39.99, 'USD', '2013-09-15')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 39.99, 'USD', 'RECURRING', 'voip-monthly-unlimited', 'voip-monthly-unlimited-evergreen', '2013-09-15', '2013-10-15')
    end

    # Upgrade to the unlimited plan
    def test_change_usage_to_recurring_after_first_invoice
      # Verify account BCD
      assert_account_bcd(0)

      bp = create_entitlement_from_plan(@account.account_id, nil, 'voip-monthly-by-usage', @user, @options)
      assert_equal('voip-monthly-by-usage', bp.plan_name)
      assert_equal(0, @account.invoices(true, @options).size)

      # Verify account BCD (SUBSCRIPTION alignment)
      assert_account_bcd(0)

      # Add usage for the month
      usage_input = [{:unit_type => 'minutes',
                      :usage_records => [{:record_date => '2013-08-01', :amount => 1},
                                         {:record_date => '2013-08-02', :amount => 1},
                                         {:record_date => '2013-08-03', :amount => 1},
                                         {:record_date => '2013-08-04', :amount => 1},
                                         {:record_date => '2013-08-05', :amount => 1},
                                         {:record_date => '2013-08-07', :amount => 1}]
                     }]
      record_usage(bp.subscription_id, usage_input, @user, @options)

      # 2013-09-01
      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # First invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 5.94, 'USD', '2013-09-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 5.94, 'USD', 'USAGE', 'voip-monthly-by-usage', 'voip-monthly-by-usage-evergreen', '2013-08-01', '2013-09-01')
      # AGGREGATE mode by default
      check_invoice_consumable_item_detail(first_invoice.items[0],
                                           [{:tier => 1, :unit_type => 'minutes', :unit_qty => 6, :tier_price => 0.99 }], 5.94)

      # 2013-09-15
      kb_clock_add_days(14, nil, @options)
      assert_equal(1, @account.invoices(true, @options).size)

      # Reset the BCD: we want both outstanding usage (nothing in this case) and new recurring charged right away
      bp.bill_cycle_day_local = 15;
      effective_from_date  = nil
      bp.update_bcd(@user, nil, nil, effective_from_date, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Second invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 0, 'USD', '2013-09-15')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 0, 'USD', 'USAGE', 'voip-monthly-by-usage', 'voip-monthly-by-usage-evergreen', '2013-09-01', '2013-09-15')
      # AGGREGATE mode by default
      check_invoice_consumable_item_detail(second_invoice.items[0],
                                           [{:tier => 1, :unit_type => 'minutes', :unit_qty => 0, :tier_price => 0.99 }], 0)

      # Verify account BCD (SUBSCRIPTION alignment)
      assert_account_bcd(0)

      # Upgrade
      requested_date = nil
      billing_policy = nil
      bp = bp.change_plan({:productName => 'Voip', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, nil, false, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      check_entitlement(bp, 'Voip', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      assert_equal('voip-monthly-unlimited', bp.plan_name)

      # Third invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 39.99, 'USD', '2013-09-15')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 39.99, 'USD', 'RECURRING', 'voip-monthly-unlimited', 'voip-monthly-unlimited-evergreen', '2013-09-15', '2013-10-15')

      # 2013-10-15
      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)

      # Fourth invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(4, all_invoices.size)
      sort_invoices!(all_invoices)
      fourth_invoice = all_invoices[3]
      check_invoice_no_balance(fourth_invoice, 39.99, 'USD', '2013-10-15')
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, 39.99, 'USD', 'RECURRING', 'voip-monthly-unlimited', 'voip-monthly-unlimited-evergreen', '2013-10-15', '2013-11-15')
    end

    # Downgrade to the usage-based plan
    def test_change_recurring_to_usage_after_first_invoice
      # Verify account BCD
      assert_account_bcd(0)

      bp = create_entitlement_from_plan(@account.account_id, nil, 'voip-monthly-unlimited', @user, @options)
      assert_equal('voip-monthly-unlimited', bp.plan_name)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Verify account BCD (SUBSCRIPTION alignment)
      assert_account_bcd(0)

      # First invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 39.99, 'USD', DEFAULT_KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 39.99, 'USD', 'RECURRING', 'voip-monthly-unlimited', 'voip-monthly-unlimited-evergreen', '2013-08-01', '2013-09-01')

      # 2013-08-15
      kb_clock_add_days(14, nil, @options)
      assert_equal(1, @account.invoices(true, @options).size)

      # Downgrade
      requested_date = nil
      billing_policy = nil
      bp = bp.change_plan({:productName => 'Voip', :billingPeriod => 'NO_BILLING_PERIOD', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, nil, false, @options)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Change is END_OF_TERM
      bp = get_subscription(bp.subscription_id, @options)
      check_entitlement(bp, 'Voip', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      assert_equal('voip-monthly-unlimited', bp.plan_name)

      # 2013-09-01
      kb_clock_add_days(17, nil, @options)
      assert_equal(1, @account.invoices(true, @options).size)

      bp = get_subscription(bp.subscription_id, @options)
      check_entitlement(bp, 'Voip', 'BASE', 'NO_BILLING_PERIOD', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      assert_equal('voip-monthly-by-usage', bp.plan_name)

      # Add usage for the month
      usage_input = [{:unit_type => 'minutes',
                      :usage_records => [{:record_date => '2013-09-01', :amount => 1},
                                         {:record_date => '2013-09-02', :amount => 1},
                                         {:record_date => '2013-09-03', :amount => 1},
                                         {:record_date => '2013-09-04', :amount => 1},
                                         {:record_date => '2013-09-05', :amount => 1},
                                         {:record_date => '2013-09-07', :amount => 1}]
                     }]
      record_usage(bp.subscription_id, usage_input, @user, @options)

      # 2013-10-01
      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Second invoice
      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 5.94, 'USD', '2013-10-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 5.94, 'USD', 'USAGE', 'voip-monthly-by-usage', 'voip-monthly-by-usage-evergreen', '2013-09-01', '2013-10-01')
      # AGGREGATE mode by default
      check_invoice_consumable_item_detail(second_invoice.items[0],
                                           [{:tier => 1, :unit_type => 'minutes', :unit_qty => 6, :tier_price => 0.99 }], 5.94)
    end

    private

    def assert_account_bcd(expected_bcd)
      assert_equal(expected_bcd, get_account(@account.account_id, true, true, @options).bill_cycle_day_local)
    end
  end

end
