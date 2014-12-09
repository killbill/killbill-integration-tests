$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestOverdue < Base

    def setup
      @user = "Overdue"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
      add_payment_method(@account.account_id, 'killbill-payment-test', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)

      @options[:pluginProperty] = []

    end

    def teardown
      teardown_base
    end

    def test_overdue_basic


      # Set auto_pay_off to avoid automatic payments that would not include properties to make
      # payment fail
      @account.set_auto_pay_off(@user, "XXX", "YYY", @options)

      # Add plugin properties to make payment fail
      add_property('TEST_MODE', 'CONTROL')
      add_property('TRANSACTION_STATUS', 'ERROR')

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)

      # Move out of trial
      kb_clock_add_days(31, nil, @options)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      # Move to first overdue phase and make a payment -- configured to fail
      kb_clock_add_days(30, nil, @options)
      begin
        pay_all_unpaid_invoices(@account.account_id, false, "500.0", @user, @options)
      rescue KillBillClient::API::InternalServerError => e
      end

      # Make sure overdue state gets re-computed
      wait_for_killbill

      overdue_result = @account.overdue(@options)
      assert_equal('OD1', overdue_result.name , 'Failed to retrieve overdue status associated to account')

      # Verify we can't change the plan anymore ()
      begin
        billing_policy = nil
        bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, nil, billing_policy, false, @options)
      rescue KillBillClient::API::BadRequest => e
      end

      # Move to next overdue stage
      kb_clock_add_days(10, nil, @options)

      # Event s associated to subscriptions should be returned see https://github.com/killbill/killbill/issues/244
      bp2 = get_subscription(bp.subscription_id, @options)

      overdue_result = @account.overdue(@options)
      assert_equal('OD2', overdue_result.name , 'Failed to retrieve overdue status associated to account')
    end

    def add_property(key, value)
      prop_test_mode = KillBillClient::Model::PluginPropertyAttributes.new
      prop_test_mode.key = key
      prop_test_mode.value = value
      @options[:pluginProperty] << prop_test_mode
    end

  end

end
