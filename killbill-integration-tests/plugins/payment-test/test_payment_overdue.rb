# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('.', __dir__)

require 'payment_test_base'

module KillBillIntegrationTests
  class TestPaymentOverdue < KillBillIntegrationTests::PaymentTestBase
    def setup
      super

      @user = 'Overdue'

      overdue_file_xml = get_resource_as_string('Overdue.xml')
      KillBillClient::Model::Overdue.upload_tenant_overdue_config_xml(overdue_file_xml, @user, 'overdue specific to this test', 'upload overdue for tenant', @options)

      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, PLUGIN_NAME, true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)

      @options[:pluginProperty] = []
    end

    def test_overdue_basic
      # Set auto_pay_off to avoid automatic payments that would not include properties to make
      # payment fail
      @account.set_auto_pay_off(@user, 'XXX', 'YYY', @options)

      # Make payment fail
      body = { 'CONFIGURE_ACTION': 'ACTION_RETURN_PLUGIN_STATUS_ERROR' }.to_json
      KillBillClient::API.post(KILLBILL_PAYMENT_TEST_PREFIX + '/configure', body, {}, @options)

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Move out of trial
      kb_clock_add_days(31, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Move to first overdue phase and make a payment -- configured to fail
      kb_clock_add_days(30, nil, @options)
      begin
        pay_all_unpaid_invoices(@account.account_id, false, '500.0', @user, @options)
      rescue KillBillClient::API::InternalServerError
      end

      # Make sure overdue state gets re-computed
      wait_for_killbill(@options)

      overdue_result = @account.overdue(@options)
      assert_equal('OD1', overdue_result.name, 'Failed to retrieve overdue status associated to account')

      # Verify we can't change the plan anymore ()
      begin
        billing_policy = nil
        bp = bp.change_plan({ productName: 'Super', billingPeriod: 'MONTHLY', priceList: 'DEFAULT' }, @user, nil, nil, nil, billing_policy, nil, false, @options)
      rescue KillBillClient::API::BadRequest
      end

      # Move to next overdue stage
      kb_clock_add_days(10, nil, @options)

      # Event s associated to subscriptions should be returned see https://github.com/killbill/killbill/issues/244
      get_subscription(bp.subscription_id, @options)

      overdue_result = @account.overdue(@options)
      assert_equal('OD2', overdue_result.name, 'Failed to retrieve overdue status associated to account')
    end
  end
end
