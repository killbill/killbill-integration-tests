# encoding: utf-8

$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

#
# Add private API to allow specifying a target phaseType when changing Plan
#
module KillBillClient
  module Model
    class Subscription

        def change_plan_with_target_phase(input, user, reason, comment, requested_date, billing_policy, target_phase_type, call_completion, options)

          params = {}
          params[:callCompletion] = call_completion
          params[:requestedDate] = requested_date unless requested_date.nil?
          params[:billingPolicy] = billing_policy unless billing_policy.nil?

          input[:accountId] = @account_id
          input[:productCategory] = @product_category

          #
          # We reuse the catalog override structure to pass the target phaseType associated with the change.
          # Array priceOverrides should have one entry and ONLY the phase_type should be set.
          #
          input[:priceOverrides] = []
          override_target_phase = KillBillClient::Model::PhasePriceOverrideAttributes.new
          override_target_phase.phase_type = target_phase_type
          input[:priceOverrides] << override_target_phase


          return self.class.put "#{KILLBILL_API_ENTITLEMENT_PREFIX}/#{@subscription_id}",
                                input.to_json,
                                params,
                                {
                                    :user => user,
                                    :reason => reason,
                                    :comment => comment,
                                }.merge(options)
        end

    end
  end
end


module KillBillIntegrationTests

  class TestEntitlementChangeSkipPhase < Base

    KB_INIT_DATE = "2016-08-01"
    KB_INIT_CLOCK = "#{KB_INIT_DATE}T06:00:00.000Z"

    def setup

      setup_base(self.method_name, DEFAULT_MULTI_TENANT_INFO, KB_INIT_CLOCK, DEFAULT_KB_ADDRESS, DEFAULT_KB_PORT)

      upload_catalog('CatalogForChangePlanPolicies.xml', false, @user, @options)
      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    #
    # We only want to see 1 TRIAL the first time when moving to a paying Plan
    #
    # Test will do multiple change of plan back and forth between Free and Paying Plan (Silver, Gold,...) all over the 7 days initial TRIAl period.

    # In order to achieve that policy is configured to CHANGE_OF_PLAN
    # when moving away from 'Free' plan, and the second time we explicitly set the PhaseType to EVERGREEN using the private api 'change_plan_with_target_phase'
    #
    def test_change_multiple_times_over_initial_trial_period_1

      # 2016-08-01
      bp = create_entitlement_base(@account.account_id, 'Free', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Free', 'BASE', 'MONTHLY', 'DEFAULT', KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 0, 'USD', KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'RECURRING', 'free-monthly', 'free-monthly-evergreen', KB_INIT_DATE, '2016-09-01')

      # 2016-08-02
      kb_clock_add_days(1, nil, @options)

      # Change plan to Silver : Keep the FULL TRIAL
      requested_date = nil
      billing_policy = "IMMEDIATE"
      bp = bp.change_plan({:productName => 'Silver', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, false, @options)
      check_entitlement(bp, 'Silver', 'BASE', 'MONTHLY', 'DEFAULT', KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 0, 'USD', '2016-08-02')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 0, 'USD', 'FIXED', 'silver-monthly', 'silver-monthly-trial', '2016-08-02', nil)


      # 2016-08-03
      kb_clock_add_days(1, nil, @options)

      # Change plan
      requested_date = nil
      billing_policy = "IMMEDIATE"
      bp = bp.change_plan({:productName => 'Free', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, false, @options)
      check_entitlement(bp, 'Free', 'BASE', 'MONTHLY', 'DEFAULT', KB_INIT_DATE, nil)

      # 2016-08-04
      kb_clock_add_days(1, nil, @options)

      # Change plan to Gold : NO TRIAL
      requested_date = nil
      billing_policy = "IMMEDIATE"
      bp = bp.change_plan_with_target_phase({:productName => 'Gold', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, :EVERGREEN, false, @options)
      check_entitlement(bp, 'Gold', 'BASE', 'MONTHLY', 'DEFAULT', KB_INIT_DATE, nil)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)


      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 27.10, 'USD', '2016-08-04')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 27.10, 'USD', 'RECURRING', 'gold-monthly', 'gold-monthly-evergreen', '2016-08-04', '2016-09-01')

    end

    #
    # We only want to see 1 TRIAL the first time when moving to a paying Plan
    #
    # Test will do multiple change of plan back and forth between Free and Paying Plan (Silver, Gold,...) after the 7 days initial TRIAl period.

    # In order to achieve that policy is configured to CHANGE_OF_PLAN
    # when moving away from 'Free' plan, and the second time we explicitly set the PhaseType to EVERGREEN using the private api 'change_plan_with_target_phase'
    #
    def test_change_multiple_times_over_initial_trial_period_2

      # 2016-08-01
      bp = create_entitlement_base(@account.account_id, 'Free', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Free', 'BASE', 'MONTHLY', 'DEFAULT', KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(1, all_invoices.size)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 0, 'USD', KB_INIT_DATE)
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 0, 'USD', 'RECURRING', 'free-monthly', 'free-monthly-evergreen', KB_INIT_DATE, '2016-09-01')

      # 2016-08-02
      kb_clock_add_days(1, nil, @options)

      # Change plan to Silver : Keep the FULL TRIAL
      requested_date = nil
      billing_policy = "IMMEDIATE"
      bp = bp.change_plan({:productName => 'Silver', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, false, @options)
      check_entitlement(bp, 'Silver', 'BASE', 'MONTHLY', 'DEFAULT', KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 0, 'USD', '2016-08-02')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 0, 'USD', 'FIXED', 'silver-monthly', 'silver-monthly-trial', '2016-08-02', nil)


      # 2016-08-03
      kb_clock_add_days(1, nil, @options)

      # Change plan
      requested_date = nil
      billing_policy = "IMMEDIATE"
      bp = bp.change_plan({:productName => 'Free', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, false, @options)
      check_entitlement(bp, 'Free', 'BASE', 'MONTHLY', 'DEFAULT', KB_INIT_DATE, nil)

      # 2016-08-08
      kb_clock_add_days(5, nil, @options)

      # Change plan to Gold : NO TRIAL
      requested_date = nil
      billing_policy = "IMMEDIATE"
      bp = bp.change_plan_with_target_phase({:productName => 'Gold', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, requested_date, billing_policy, :EVERGREEN, false, @options)
      check_entitlement(bp, 'Gold', 'BASE', 'MONTHLY', 'DEFAULT', KB_INIT_DATE, nil)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)


      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 23.23, 'USD', '2016-08-08')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 23.23, 'USD', 'RECURRING', 'gold-monthly', 'gold-monthly-evergreen', '2016-08-08', '2016-09-01')

    end


  end
end
