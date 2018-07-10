# encoding: utf-8

$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestEntitlementCreateTest < Base

    def setup
      setup_base
      #
      # Catalog only contains BASE 'Sports' and AO 'OilSlick', 'RemoteControl' where those have 3 phase (TRIAL, DISCOUNT, EVERGREEN)
      #
      upload_catalog('ReducedSpyCarAdvancedWithThreePhasesAddOns.xml', false, @user, @options)
      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    def test_create_bp_skip_trial

      bp = create_entitlement_base_skip_phase(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', 'EVERGREEN', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      assert_equal('EVERGREEN', bp.phase_type)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(1, all_invoices.size)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 500.0, 'USD', '2013-08-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 500.0, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-01', '2013-09-01')
    end

    def test_create_ao_bundle_aligned_skip_trial

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Move clock to create ADD_ON a bit later (BP still in trial)
      kb_clock_add_days(15, nil, @options) # "2013-08-16"

      # Create Add-on
      ao_entitlement = create_entitlement_ao_skip_phase(@account.account_id, bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', 'DISCOUNT', @user, @options)
      check_entitlement(ao_entitlement, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-16", nil)
      assert_equal('DISCOUNT', ao_entitlement.phase_type)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)


      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 1.94, 'USD', '2013-08-16')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 1.94, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-discount', '2013-08-16', '2013-08-31')

      kb_clock_add_days(15, nil, @options) # "2013-08-31"

      #
      # Because we are BUNDLE aligned the discount period that starts on the 2013-08-01 and because it lasts a month we see a first long pro-ration until 2013-09-01 and then
      # when we move the clock again by ONE day, we see the remaining piece.
      #
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]
      sort_items_by_descending_price!(third_invoice.items)
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 500, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 0.13, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-discount', '2013-08-31', '2013-09-01')

      kb_clock_add_days(1, nil, @options) # "2013-09-01"

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(4, all_invoices.size)
      fourth_invoice = all_invoices[3]
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, 7.44, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-evergreen', '2013-09-01', '2013-09-30')

    end

    def test_create_ao_subscription_aligned_skip_trial


      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Move clock to create ADD_ON a bit later (BP still in trial)
      kb_clock_add_days(15, nil, @options) # "2013-08-16"

      # Create Add-on
      ao_entitlement = create_entitlement_ao_skip_phase(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', 'DISCOUNT', @user, @options)
      check_entitlement(ao_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-08-16", nil)
      assert_equal('DISCOUNT', ao_entitlement.phase_type)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)


      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 3.87, 'USD', '2013-08-16')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 3.87, 'USD', 'RECURRING', 'remotecontrol-monthly', 'remotecontrol-monthly-discount', '2013-08-16', '2013-08-31')

      kb_clock_add_days(15, nil, @options) # "2013-08-31"
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)


      #
      # Because we are SUBSCRIPTION aligned the discount period that starts on the 2013-08-16 and because it lasts a month we see a first pro-ration until 2013-09-01 and then
      # when we move the clock again by 16 day, we see the remaining piece.
      #
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]
      sort_items_by_descending_price!(third_invoice.items)
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 500, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 4.27, 'USD', 'RECURRING', 'remotecontrol-monthly', 'remotecontrol-monthly-discount', '2013-08-31', '2013-09-16')

      kb_clock_add_days(16, nil, @options) # "2013-09-16"
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(4, all_invoices.size)
      fourth_invoice = all_invoices[3]
      sort_items_by_descending_price!(fourth_invoice.items)
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, 8.11, 'USD', 'RECURRING', 'remotecontrol-monthly', 'remotecontrol-monthly-evergreen', '2013-09-16', '2013-09-30')


      # Change plan EOT
      ao_entitlement = ao_entitlement.change_plan({:productName => 'RemoteControlAdvanced', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, nil, nil, nil, false, @options)
      check_entitlement(ao_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', '2013-08-16', nil)

      # Change plan becomes effective: We verify that the changePlan correctly skips the initial TRIAL for the new plan
      kb_clock_add_days(14, nil, @options) # "2013-09-30"
      wait_for_expected_clause(5, @account, @options, &@proc_account_invoices_nb)

      ao_entitlement = get_subscription(ao_entitlement.subscription_id, @options)
      assert_equal('EVERGREEN', ao_entitlement.phase_type)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(5, all_invoices.size)
      fifth_invoice = all_invoices[4]
      sort_items_by_descending_price!(fifth_invoice.items)
      check_invoice_item(fifth_invoice.items[0], fifth_invoice.invoice_id, 500, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-30', '2013-10-31')
      check_invoice_item(fifth_invoice.items[1], fifth_invoice.invoice_id, 37.95, 'USD', 'RECURRING', 'remotecontroladvanced-monthly', 'remotecontroladvanced-monthly-evergreen', '2013-09-30', '2013-10-31')

    end

    private

    def sort_items_by_descending_price!(items)
      items.sort! do |a, b|
        b.amount <=> a.amount
      end

    end
  end
end
