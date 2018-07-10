$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestPriceOverride < Base

    def setup
      setup_base
      load_default_catalog
      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    def test_override_fixed_price_in_trial_with_phase_type
      overrides = []
      override_trial = KillBillClient::Model::PhasePriceAttributes.new
      override_trial.phase_type = 'TRIAL'
      override_trial.fixed_price = 10.0
      overrides << override_trial

      create_entitlement_base_with_overrides(@account.account_id, 'Standard', 'MONTHLY', 'DEFAULT', overrides, @user, @options)
      check_next_invoice_amount(1, 10.0, '2013-08-01', @account, @options, &@proc_account_invoices_nb)
    end

    def test_override_fixed_price_in_trial_with_phase_name=
      overrides = []
      override_trial = KillBillClient::Model::PhasePriceAttributes.new
      override_trial.phase_name = 'standard-monthly-trial'
      override_trial.fixed_price = 20.0
      overrides << override_trial

      create_entitlement_base_with_overrides(@account.account_id, 'Standard', 'MONTHLY', 'DEFAULT', overrides, @user, @options)
      check_next_invoice_amount(1, 20.0, '2013-08-01', @account, @options, &@proc_account_invoices_nb)
    end

    def test_override_recurring_price_in_evergreen_with_phase_name
      overrides = []
      override_trial = KillBillClient::Model::PhasePriceAttributes.new
      override_trial.phase_name = 'standard-monthly-evergreen'
      override_trial.recurring_price = 1345.0
      overrides << override_trial

      create_entitlement_base_with_overrides(@account.account_id, 'Standard', 'MONTHLY', 'DEFAULT', overrides, @user, @options)
      check_next_invoice_amount(1, 0.0, '2013-08-01', @account, @options, &@proc_account_invoices_nb)

      kb_clock_add_days(30, nil, @options)
      check_next_invoice_amount(2, 1345.0, '2013-08-31', @account, @options, &@proc_account_invoices_nb)

      kb_clock_add_months(1, nil, @options)
      check_next_invoice_amount(3, 1345.0, '2013-09-30', @account, @options, &@proc_account_invoices_nb)
    end

    def test_override_recurring_price_in_evergreen_with_phase_type
      overrides = []
      override_trial = KillBillClient::Model::PhasePriceAttributes.new
      override_trial.phase_type = 'EVERGREEN'
      override_trial.recurring_price = 500.0
      overrides << override_trial

      create_entitlement_base_with_overrides(@account.account_id, 'Standard', 'MONTHLY', 'DEFAULT', overrides, @user, @options)
      check_next_invoice_amount(1, 0.0, '2013-08-01', @account, @options, &@proc_account_invoices_nb)

      kb_clock_add_days(30, nil, @options)
      check_next_invoice_amount(2, 500.0, '2013-08-31', @account, @options, &@proc_account_invoices_nb)

      kb_clock_add_months(1, nil, @options)
      check_next_invoice_amount(3, 500.0, '2013-09-30', @account, @options, &@proc_account_invoices_nb)
    end

    def test_change_plan_with_override
      overrides1 = []
      override1 = KillBillClient::Model::PhasePriceAttributes.new
      override1.phase_type = 'EVERGREEN'
      override1.recurring_price = 500.0
      overrides1 << override1

      bp = create_entitlement_base_with_overrides(@account.account_id, 'Standard', 'MONTHLY', 'DEFAULT', overrides1, @user, @options)
      check_next_invoice_amount(1, 0.0, '2013-08-01', @account, @options, &@proc_account_invoices_nb)

      kb_clock_add_days(30, nil, @options)
      check_next_invoice_amount(2, 500.0, '2013-08-31', @account, @options, &@proc_account_invoices_nb)

      overrides2 = []
      override2 = KillBillClient::Model::PhasePriceAttributes.new
      override2.phase_type = 'EVERGREEN'
      override2.recurring_price = 1000.0
      overrides2 << override2

      requested_date = nil
      billing_policy = "END_OF_TERM"
      bp = bp.change_plan({:productName => 'Standard', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT', :priceOverrides => overrides2}, @user, nil, nil, requested_date, billing_policy, nil, false, @options)

      kb_clock_add_months(1, nil, @options)
      check_next_invoice_amount(3, 1000.0, '2013-09-30', @account, @options, &@proc_account_invoices_nb)

      kb_clock_add_days(31, nil, @options)
      check_next_invoice_amount(4, 1000.0, '2013-10-31', @account, @options, &@proc_account_invoices_nb)
    end

    def test_ao_with_override
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      overrides1 = []
      override1 = KillBillClient::Model::PhasePriceAttributes.new
      override1.phase_type = 'DISCOUNT'
      override1.recurring_price = 10.00
      overrides1 << override1

      # (Bundle Aligned) => leading pro-ration up to 08-31 => amount is less than 10.00 (9.68)
      create_entitlement_ao_with_overrides(@account.account_id, bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', overrides1, @user, @options)
      check_next_invoice_amount(2, 9.68, '2013-08-01', @account, @options, &@proc_account_invoices_nb)

      # Let's do another one (same override)
      # (Bundle Aligned) => leading pro-ration up to 08-31 => amount is less than 10.00 (9.68)
      create_entitlement_ao_with_overrides(@account.account_id, bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', overrides1, @user, @options)
      check_next_invoice_amount(3, 9.68, '2013-08-01', @account, @options, &@proc_account_invoices_nb)
    end
  end
end
