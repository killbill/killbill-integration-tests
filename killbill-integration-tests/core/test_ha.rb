$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestHA < Base

    def setup
      setup_base
      load_default_catalog
      @parent_account = create_account(@user, @options)
      @parent_account = get_account(@parent_account.account_id, false, false, @options)
    end

    def teardown
      teardown_base
    end

    #
    # Basic simple recurring subscription use case
    #
    def test_basic_regular_child_subscription

      add_payment_method(@parent_account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      @child_account = create_child_account(@parent_account)

      bp = create_entitlement_base(@child_account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 1, 0, 'USD', DEFAULT_KB_INIT_DATE)
      check_child_invoice_item(child_invoice, 1, 0, 'USD', 'FIXED', 'sports-monthly', 'sports-monthly-trial', '2013-08-01', nil)
      check_account_balance(@child_account, 0, 0)

      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(1, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 1, 0, 'USD', DEFAULT_KB_INIT_DATE)
      check_parent_invoice_item(parent_invoice, 1, 0, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)

      # Get out of trial
      kb_clock_add_days(29, nil, @options)
      wait_for_expected_clause(2, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 2, 500.0, 'USD', '2013-08-31')
      check_child_invoice_item(child_invoice, 1, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      # Since invoice parent is in DRAFT we see a balance of 0 until this has been committed so child balance is also 0
      check_account_balance(@child_account, 0, 0)

      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 2, 500, 'USD', '2013-08-31')
      check_parent_invoice_item(parent_invoice, 1, 500, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)
      # Child balance should also show as 0
      check_account_balance(@child_account, 0, 0)


      # Next recurring
      kb_clock_add_days(29, nil, @options)
      wait_for_expected_clause(3, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 3, 500.0, 'USD', '2013-09-30')
      check_child_invoice_item(child_invoice, 1, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-30', '2013-10-31')
      check_account_balance(@child_account, 0, 0)

      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(3, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 3, 500, 'USD', '2013-09-30')
      check_parent_invoice_item(parent_invoice, 1, 500, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)
      check_account_balance(@child_account, 0, 0)
    end

    #
    # Cancellation EOT PRIOR parent SUMMARY closes
    #
    def test_cancel_EOT_before_summary_closes

      add_payment_method(@parent_account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      @child_account = create_child_account(@parent_account)

      bp = create_entitlement_base(@child_account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @child_account, @options, &@proc_account_invoices_nb)


      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(1, @parent_account, @options, &@proc_account_invoices_nb)

      # Get out of trial
      kb_clock_add_days(29, nil, @options)
      wait_for_expected_clause(2, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 2, 500.0, 'USD', '2013-08-31')
      check_child_invoice_item(child_invoice, 1, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      # Since invoice parent is in DRAFT we see a balance of 0 until this has been committed so child balance is also 0
      check_account_balance(@child_account, 0, 0)

      # Cancel BP
      bp.cancel(@user, nil, nil, nil, "END_OF_TERM", "END_OF_TERM", nil, @options)

      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 2, 500, 'USD', '2013-08-31')
      check_parent_invoice_item(parent_invoice, 1, 500, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)
      check_account_balance(@child_account, 0, 0)

      # Move again to next month
      kb_clock_add_days(29, nil, @options)
      sleep 2.0
      child_account_invoices = @child_account.invoices(true, @options)
      assert_equal(2, child_account_invoices.size)

      parent_account_invoices = @parent_account.invoices(true, @options)
      assert_equal(2, parent_account_invoices.size)
    end

    #
    # Cancellation EOT AFTER parent SUMMARY closes
    #
    def test_cancel_EOT_after_summary_closes

      add_payment_method(@parent_account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      @child_account = create_child_account(@parent_account)

      bp = create_entitlement_base(@child_account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @child_account, @options, &@proc_account_invoices_nb)


      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(1, @parent_account, @options, &@proc_account_invoices_nb)

      # Get out of trial
      kb_clock_add_days(29, nil, @options)
      wait_for_expected_clause(2, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 2, 500.0, 'USD', '2013-08-31')
      check_child_invoice_item(child_invoice, 1, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      # Since invoice parent is in DRAFT we see a balance of 0 until this has been committed so child balance is also 0
      check_account_balance(@child_account, 0, 0)

      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 2, 500, 'USD', '2013-08-31')
      check_parent_invoice_item(parent_invoice, 1, 500, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)
      check_account_balance(@child_account, 0, 0)

      # Cancel BP
      bp.cancel(@user, nil, nil, nil, "END_OF_TERM", "END_OF_TERM", nil, @options)

      # Move again to next month
      kb_clock_add_days(29, nil, @options)
      sleep 2.0
      child_account_invoices = @child_account.invoices(true, @options)
      assert_equal(2, child_account_invoices.size)

      parent_account_invoices = @parent_account.invoices(true, @options)
      assert_equal(2, parent_account_invoices.size)
    end

    #
    # Cancellation IMMEDIATE PRIOR parent SUMMARY closes
    #
    def test_cancel_IMM_prior_summary_closes

      add_payment_method(@parent_account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      @child_account = create_child_account(@parent_account)

      bp = create_entitlement_base(@child_account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @child_account, @options, &@proc_account_invoices_nb)


      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(1, @parent_account, @options, &@proc_account_invoices_nb)

      # Get out of trial
      kb_clock_add_days(29, nil, @options)
      wait_for_expected_clause(2, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 2, 500.0, 'USD', '2013-08-31')
      check_child_invoice_item(child_invoice, 1, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      # Since invoice parent is in DRAFT we see a balance of 0 until this has been committed so child balance is also 0
      check_account_balance(@child_account, 0, 0)

      # Cancel BP
      bp.cancel(@user, nil, nil, nil, "IMMEDIATE", "IMMEDIATE", nil, @options)
      # New invoice with REPAIR_ADJ and CBA_ADJ
      wait_for_expected_clause(3, @child_account, @options, &@proc_account_invoices_nb)

      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 2, 0, 'USD', '2013-08-31')
      check_parent_invoice_item(parent_invoice, 1, 0, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)
      check_account_balance(@child_account, 0, 0)


      # Move again to next month
      kb_clock_add_days(29, nil, @options)
      sleep 2.0
      child_account_invoices = @child_account.invoices(true, @options)
      assert_equal(3, child_account_invoices.size)

      parent_account_invoices = @parent_account.invoices(true, @options)
      assert_equal(2, parent_account_invoices.size)

    end

    #
    # Cancellation IMMEDIATE AFTER parent SUMMARY closes
    #
    def test_cancel_IMM_after_summary_closes

      add_payment_method(@parent_account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      @child_account = create_child_account(@parent_account)

      bp = create_entitlement_base(@child_account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @child_account, @options, &@proc_account_invoices_nb)


      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(1, @parent_account, @options, &@proc_account_invoices_nb)

      # Get out of trial
      kb_clock_add_days(29, nil, @options)
      wait_for_expected_clause(2, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 2, 500.0, 'USD', '2013-08-31')
      check_child_invoice_item(child_invoice, 1, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      # Since invoice parent is in DRAFT we see a balance of 0 until this has been committed so child balance is also 0
      check_account_balance(@child_account, 0, 0)

      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 2, 500, 'USD', '2013-08-31')
      check_parent_invoice_item(parent_invoice, 1, 500, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)
      check_account_balance(@child_account, 0, 0)

      # Cancel BP
      bp.cancel(@user, nil, nil, nil, "IMMEDIATE", "IMMEDIATE", nil, @options)
      # New invoice with REPAIR_ADJ and CBA_ADJ
      wait_for_expected_clause(3, @child_account, @options, &@proc_account_invoices_nb)

      # Verify there is **NO** new invoice for the parent (since the previous cancellation only resulted in a child account credit)
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)

      # Move again to next month
      kb_clock_add_days(29, nil, @options)
      sleep 2.0
      child_account_invoices = @child_account.invoices(true, @options)
      assert_equal(3, child_account_invoices.size)

      parent_account_invoices = @parent_account.invoices(true, @options)
      assert_equal(2, parent_account_invoices.size)
    end


    #
    # Create  a BP + AO
    # Initially BP and AO are not aligned (different invoices) but after a few period they become aligned
    #
    # We verify that non aligned subscriptions also appears on different parent invoices
    # We verify that aligned subscriptions  appear on the same parent invoice
    #
    def test_non_aligned_and_aligned_subscriptions

      add_payment_method(@parent_account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      @child_account = create_child_account(@parent_account)

      bp = create_entitlement_base(@child_account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @child_account, @options, &@proc_account_invoices_nb)

      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(1, @parent_account, @options, &@proc_account_invoices_nb)

      # Move clock and create Add-on 1 (BP still in trial)
      kb_clock_add_days(3, nil, @options) # 05/08/2013

      # Second invoice 05/08/2013 -> 31/08/2013
      ao = create_entitlement_ao(@child_account.account_id, bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options) # (Bundle Aligned)
      check_entitlement(ao, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-05", nil)
      wait_for_expected_clause(2, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 2, 3.35, 'USD', "2013-08-05")
      check_child_invoice_item(child_invoice, 1, 3.35, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-discount', '2013-08-05', '2013-08-31')
      # Since invoice parent is in DRAFT we see a balance of 0 until this has been committed so child balance is also 0
      check_account_balance(@child_account, 0, 0)

      # Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 2, 3.35, 'USD', '2013-08-05')
      check_parent_invoice_item(parent_invoice, 1, 3.35, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)
      check_account_balance(@child_account, 0, 0)

      # Get out of trial (the OilSlick phase is on 2013-09-01, so we will see a small pro-ration)
      kb_clock_add_days(25, nil, @options)
      wait_for_expected_clause(3, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 3, 500.13, 'USD', '2013-08-31')
      check_child_invoice_item(child_invoice, 1, 0.13, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-discount', '2013-08-31', '2013-09-01')
      check_child_invoice_item(child_invoice, 2, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_account_balance(@child_account, 0, 0)

      # Verify we see the parent invoice (and interestingly enough we also have a new invoice for the child for the OilSlick PHASE event)
      kb_clock_add_days(1, nil, @options)
      # Tricky we have to wait for 4 invoices because of the DRAFT created
      wait_for_expected_clause(4, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 3, 500.13, 'USD', '2013-08-31', false)
      check_parent_invoice_item(parent_invoice, 1, 500.13, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)

      wait_for_expected_clause(4, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 4, 7.44, 'USD', '2013-09-01')
      check_child_invoice_item(child_invoice, 1, 7.44, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-evergreen', '2013-09-01', '2013-09-30')
      check_account_balance(@child_account, 0, 0)

      # Verify we see the parent invoice for theOilSlick PHASE event)
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(4, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 4, 7.44, 'USD', '2013-09-01')
      check_parent_invoice_item(parent_invoice, 1, 7.44, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)
      check_account_balance(@child_account, 0, 0)


      # Finally we get the alignment
      kb_clock_add_days(28, nil, @options)
      wait_for_expected_clause(5, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 5, 507.95, 'USD', '2013-09-30')
      check_child_invoice_item(child_invoice, 1, 7.95, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-evergreen', '2013-09-30', '2013-10-31')
      check_child_invoice_item(child_invoice, 2, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-30', '2013-10-31')
      check_account_balance(@child_account, 0, 0)

      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(5, @parent_account, @options, &@proc_account_invoices_nb)

      parent_invoice = get_and_check_parent_invoice(@parent_account, 5, 507.95, 'USD', '2013-09-30')
      check_parent_invoice_item(parent_invoice, 1, 507.95, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)
      check_account_balance(@child_account, 0, 0)
    end


    def test_upgrade_plan_immediate

      add_payment_method(@parent_account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      @child_account = create_child_account(@parent_account)

      bp = create_entitlement_base(@child_account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @child_account, @options, &@proc_account_invoices_nb)

      # '2013-08-02' :Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(1, @parent_account, @options, &@proc_account_invoices_nb)

      # Get out of trial
      kb_clock_add_days(29, nil, @options)
      wait_for_expected_clause(2, @child_account, @options, &@proc_account_invoices_nb)

      # '2013-09-01' : Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)

      # Upgrade to Super IMMEDIATELY
      bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, nil, nil, nil, false, @options)
      wait_for_expected_clause(3, @child_account, @options, &@proc_account_invoices_nb)

      # '2013-09-02' Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(3, @parent_account, @options, &@proc_account_invoices_nb)

      # '2013-09-30' : Next recurring
      kb_clock_add_days(28, nil, @options)
      wait_for_expected_clause(4, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 4, 1000.00, 'USD', '2013-09-30')
      check_child_invoice_item(child_invoice, 1, 1000.00, 'USD', 'RECURRING', 'super-monthly', 'super-monthly-evergreen', '2013-09-30', '2013-10-31')
      # Since invoice parent is in DRAFT we see a balance of 0 until this has been committed so child balance is also 0
      check_account_balance(@child_account, 0, 0)

      # '2013-10-01' : Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(4, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 4, 1000.00, 'USD', '2013-09-30')
      check_parent_invoice_item(parent_invoice, 1, 1000.00, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)
      check_account_balance(@child_account, 0, 0)
    end


    def test_downgrade_plan_immediate

      add_payment_method(@parent_account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      @child_account = create_child_account(@parent_account)

      bp = create_entitlement_base(@child_account.account_id, 'Super', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @child_account, @options, &@proc_account_invoices_nb)

      # '2013-08-02' :Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(1, @parent_account, @options, &@proc_account_invoices_nb)

      # Get out of trial
      kb_clock_add_days(29, nil, @options)
      wait_for_expected_clause(2, @child_account, @options, &@proc_account_invoices_nb)

      # '2013-09-01' : Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)

      # Downgrade to Sport IMMEDIATELY
      bp = bp.change_plan({:productName => 'Sports', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, nil, 'IMMEDIATE', nil, false, @options)
      wait_for_expected_clause(3, @child_account, @options, &@proc_account_invoices_nb)

      # '2013-09-02' Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(3, @parent_account, @options, &@proc_account_invoices_nb)

      # '2013-09-30' : Next recurring
      kb_clock_add_days(28, nil, @options)
      wait_for_expected_clause(4, @child_account, @options, &@proc_account_invoices_nb)
      child_invoice = get_and_check_child_invoice(@child_account, 4, 500.00, 'USD', '2013-09-30')
      check_child_invoice_item(child_invoice, 1, -498.93, 'USD', 'CBA_ADJ', nil, nil, '2013-09-30', '2013-09-30')
      check_child_invoice_item(child_invoice, 2, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-30', '2013-10-31')
      # Since invoice parent is in DRAFT we see a balance of 0 until this has been committed so child balance is also 0
      check_account_balance(@child_account, 0, 0)

      # '2013-10-01' : Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(4, @parent_account, @options, &@proc_account_invoices_nb)
      parent_invoice = get_and_check_parent_invoice(@parent_account, 4, 1.07, 'USD', '2013-09-30')
      check_parent_invoice_item(parent_invoice, 1, 1.07, 'USD', @child_account.account_id)
      check_account_balance(@parent_account, 0, 0)
      check_account_balance(@child_account, 0, 0)
    end

    def test_child_credit_transfer

      add_payment_method(@parent_account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      @child_account = create_child_account(@parent_account)
      create_account_credit(@child_account.account_id, 12.0, 'USD', 'Child credit', @user, @options)

      check_account_balance(@child_account, -12.0, 12.0)
      check_account_balance(@parent_account, 0.0, 0.0)

      @child_account.transfer_child_credit(@user, nil, nil, @options)

      check_account_balance(@parent_account, -12.0, 12.0)
      check_account_balance(@child_account, 0.0, 0.0)
    end

    def test_invoice_item_adj_before_parent_commit

      add_payment_method(@parent_account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      @child_account = create_child_account(@parent_account)

      create_entitlement_base(@child_account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @child_account, @options, &@proc_account_invoices_nb)

      # '2013-08-02' :Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(1, @parent_account, @options, &@proc_account_invoices_nb)

      # Get out of trial
      kb_clock_add_days(29, nil, @options)
      wait_for_expected_clause(2, @child_account, @options, &@proc_account_invoices_nb)

      child_invoice = get_and_check_child_invoice(@child_account, 2, 500.00, 'USD', '2013-08-31')

      adjust_invoice_item(@child_account.account_id, child_invoice.invoice_id, child_invoice.items[0].invoice_item_id, 100.0, 'USD', 'Free adjustment: good customer', @user, @options)

      get_and_check_child_invoice(@child_account, 2, 400.00, 'USD', '2013-08-31')

      # '2013-09-01' : Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)

      get_and_check_parent_invoice(@parent_account, 2, 400.00, 'USD', '2013-08-31')
    end

    def test_invoice_item_adj_after_parent_commit

      add_payment_method(@parent_account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      @child_account = create_child_account(@parent_account)

      create_entitlement_base(@child_account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @child_account, @options, &@proc_account_invoices_nb)

      # '2013-08-02' :Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(1, @parent_account, @options, &@proc_account_invoices_nb)

      # Get out of trial
      kb_clock_add_days(29, nil, @options)
      wait_for_expected_clause(2, @child_account, @options, &@proc_account_invoices_nb)

      # '2013-09-01' : Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)

      child_invoice = get_and_check_child_invoice(@child_account, 2, 500.00, 'USD', '2013-08-31')
      get_and_check_parent_invoice(@parent_account, 2, 500.00, 'USD', '2013-08-31')

      adjust_invoice_item(@child_account.account_id, child_invoice.invoice_id, child_invoice.items[0].invoice_item_id, 100.0, 'USD', 'Free adjustment: good customer', @user, @options)

      get_and_check_child_invoice(@child_account, 2, 400.00, 'USD', '2013-08-31')
      # Item is ignored by the parent (invoice was already paid, so credit is available on the child and not visible on parent)
      get_and_check_parent_invoice(@parent_account, 2, 500.00, 'USD', '2013-08-31')
    end

    def test_invoice_item_adj_no_parent_payment

      @child_account = create_child_account(@parent_account)

      create_entitlement_base(@child_account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @child_account, @options, &@proc_account_invoices_nb)

      # '2013-08-02' :Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(1, @parent_account, @options, &@proc_account_invoices_nb)

      # Get out of trial
      kb_clock_add_days(29, nil, @options)
      wait_for_expected_clause(2, @child_account, @options, &@proc_account_invoices_nb)

      # '2013-09-01' : Verify we see the parent invoice
      kb_clock_add_days(1, nil, @options)
      wait_for_expected_clause(2, @parent_account, @options, &@proc_account_invoices_nb)

      child_invoice = get_and_check_child_invoice(@child_account, 2, 500.00, 'USD', '2013-08-31')
      get_and_check_parent_invoice(@parent_account, 2, 500.00, 'USD', '2013-08-31')
      check_account_balance(@parent_account, 500.00, nil)

      adjust_invoice_item(@child_account.account_id, child_invoice.invoice_id, child_invoice.items[0].invoice_item_id, 100.0, 'USD', 'Free adjustment: good customer', @user, @options)

      get_and_check_child_invoice(@child_account, 2, 400.00, 'USD', '2013-08-31')
      get_and_check_parent_invoice(@parent_account, 2, 400.00, 'USD', '2013-08-31')
    end

    private


    def get_and_check_parent_invoice(parent_account, invoice_cnt, amount, currency, invoice_date, verify_count=true)
      get_and_check_account_invoice(parent_account, invoice_cnt, amount, currency, invoice_date, verify_count)
    end

    def get_and_check_child_invoice(child_account, invoice_cnt, amount, currency, invoice_date, verify_count=true)
      get_and_check_account_invoice(child_account, invoice_cnt, amount, currency, invoice_date, verify_count)
    end


    def get_and_check_account_invoice(account, invoice_cnt, amount, currency, invoice_date, verify_count=true)
      all_account_invoices = account.invoices(true, @options)
      assert_equal(invoice_cnt, all_account_invoices.size) if verify_count
      sort_invoices!(all_account_invoices)
      account_invoice = all_account_invoices[invoice_cnt - 1]
      check_invoice_no_balance(account_invoice, amount, currency, invoice_date)
      # Sort children items by amount
      sort_invoice_items!([account_invoice])
      account_invoice
    end

    def check_account_balance(account, balance, credit=nil)
      refreshed_account = get_account(account.account_id, true, true, @options)
      assert_equal(balance, refreshed_account.account_balance)
      assert_equal(credit, refreshed_account.account_cba) if credit
    end

    def check_child_invoice_item(child_invoice, item_cnt, amount, currency, type, plan_name, phase_name, start_date, end_date)
      check_invoice_item(child_invoice.items[item_cnt - 1], child_invoice.invoice_id, amount, currency, type, plan_name, phase_name, start_date, end_date)
    end

    def check_parent_invoice_item(parent_invoice, item_cnt, amount, currency, child_account_id)
      ii = parent_invoice.items[item_cnt - 1]
      check_invoice_item(ii, parent_invoice.invoice_id, amount, currency, 'PARENT_SUMMARY', nil, nil, nil, nil)
      assert_equal(child_account_id, ii.child_account_id, "invoice_item #{ii.invoice_item_id}")
    end

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
