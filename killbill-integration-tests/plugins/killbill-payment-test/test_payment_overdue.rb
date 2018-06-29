$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)
$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'plugin_base'

module KillBillIntegrationTests

  class TestPaymentOverdue < KillBillIntegrationTests::PluginBase

    PLUGIN_KEY = "payment-test"
    # Default to latest
    PLUGIN_VERSION = nil


    PLUGIN_PROPS = [{:key => 'pluginArtifactId', :value => 'payment-test-plugin'},
                    {:key => 'pluginGroupId', :value => 'org.kill-bill.billing.plugin.ruby'},
                    {:key => 'pluginType', :value => 'ruby'},
    ]

    def setup
      @user = "Overdue"
      setup_plugin_base(DEFAULT_KB_INIT_CLOCK, PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)

      overdue_file_xml = get_resource_as_string("Overdue.xml")
      KillBillClient::Model::Overdue.upload_tenant_overdue_config_xml(overdue_file_xml, @user, "overdue specific to this test", "upload overdue for tenant", @options)

      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, 'killbill-payment-test', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)

      @options[:pluginProperty] = []

    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY)
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
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # Move out of trial
      kb_clock_add_days(31, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Move to first overdue phase and make a payment -- configured to fail
      kb_clock_add_days(30, nil, @options)
      begin
        pay_all_unpaid_invoices(@account.account_id, false, "500.0", @user, @options)
      rescue KillBillClient::API::InternalServerError => e
      end

      # Make sure overdue state gets re-computed
      wait_for_killbill(@options)

      overdue_result = @account.overdue(@options)
      assert_equal('OD1', overdue_result.name , 'Failed to retrieve overdue status associated to account')

      # Verify we can't change the plan anymore ()
      begin
        billing_policy = nil
        bp = bp.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, nil, billing_policy, nil, false, @options)
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
