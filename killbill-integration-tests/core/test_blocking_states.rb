$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestBlockingStates < Base

    def setup
      setup_base

      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
    end

    def teardown
      teardown_base
    end

    def test_service_state_changes
      # Start one year earlier than any other test (because we end up moving the clock by 11 months so we don't want all kinds of parasite account to start kicking it and impacting the timing of our test)
      kb_clock_set('2012-08-01T06:00:00.000Z', nil, @options)

      catalog_file_xml = get_resource_as_string("Catalog-Simple.xml")
      KillBillClient::Model::Catalog.upload_tenant_catalog(catalog_file_xml, @user, 'New Catalog Version', 'Upload catalog for tenant', @options)

      # Disable invoice processing for account
      @account.set_auto_invoicing_off(@user, 'test_service_state_changes', 'Test service state change events', @options)

      #
      # SERVICE_STATE_CHANGE, block_entitlement=false, block_billing=false
      #
      bp1 = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp1, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', '2012-08-01', nil)

      set_bundle_blocking_state(bp1.bundle_id, 'STATE1', 'ServiceStateService', false, false, false, nil, @user, @options)

      bp1_subscriptions = get_subscriptions(bp1.bundle_id, @options)
      bp1 = bp1_subscriptions.find { |s| s.subscription_id == bp1.subscription_id }

      events = [{:type                    => 'START_ENTITLEMENT',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => false,
                 :is_blocked_entitlement => false,
                 :service_name           => 'entitlement-service',
                 :service_state_name     => 'ENT_STARTED'},
                {:type                   => 'START_BILLING',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => false,
                 :is_blocked_entitlement => false,
                 :service_name           => 'billing-service',
                 :service_state_name     => 'START_BILLING'},
                {:type                   => 'SERVICE_STATE_CHANGE',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => false,
                 :is_blocked_entitlement => false,
                 :service_name           => 'ServiceStateService',
                 :service_state_name     => 'STATE1'}]

      check_events(events, bp1.events)

      #
      # SERVICE_STATE_CHANGE, block_entitlement=true, block_billing=false
      #
      bp2 = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp2, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', '2012-08-01', nil)

      set_bundle_blocking_state(bp2.bundle_id, 'STATE2', 'ServiceStateService', false, true, false, nil, @user, @options)


      bp2_subscriptions = get_subscriptions(bp2.bundle_id, @options)
      bp2 = bp2_subscriptions.find { |s| s.subscription_id == bp2.subscription_id }

      events = [{:type                    => 'START_ENTITLEMENT',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => false,
                 :is_blocked_entitlement => false,
                 :service_name           => 'entitlement-service',
                 :service_state_name     => 'ENT_STARTED'},
                {:type                   => 'START_BILLING',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => false,
                 :is_blocked_entitlement => false,
                 :service_name           => 'billing-service',
                 :service_state_name     => 'START_BILLING'},
                {:type                   => 'PAUSE_ENTITLEMENT',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => false,
                 :is_blocked_entitlement => true,
                 :service_name           => 'ServiceStateService',
                 :service_state_name     => 'STATE2'}]

      check_events(events, bp2.events)

      #
      # SERVICE_STATE_CHANGE, block_entitlement=false, block_billing=true
      #
      bp3 = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp3, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', '2012-08-01', nil)

      set_bundle_blocking_state(bp3.bundle_id, 'STATE3', 'ServiceStateService', false, false, true, nil, @user, @options)


      bp3_subscriptions = get_subscriptions(bp3.bundle_id, @options)
      bp3 = bp3_subscriptions.find { |s| s.subscription_id == bp3.subscription_id }

      events = [{:type                    => 'START_ENTITLEMENT',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => false,
                 :is_blocked_entitlement => false,
                 :service_name           => 'entitlement-service',
                 :service_state_name     => 'ENT_STARTED'},
                {:type                   => 'START_BILLING',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => false,
                 :is_blocked_entitlement => false,
                 :service_name           => 'billing-service',
                 :service_state_name     => 'START_BILLING'},
                {:type                   => 'PAUSE_BILLING',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => true,
                 :is_blocked_entitlement => false,
                 :service_name           => 'ServiceStateService',
                 :service_state_name     => 'STATE3'}]

      check_events(events, bp3.events)

      #
      # SERVICE_STATE_CHANGE, block_entitlement=true, block_billing=true
      #
      bp4 = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp4, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', '2012-08-01', nil)

      set_bundle_blocking_state(bp4.bundle_id, 'STATE4a', 'ServiceStateService', false, true, true, nil, @user, @options)
      # Add another one with same flags
      set_bundle_blocking_state(bp4.bundle_id, 'STATE4b', 'ServiceStateService', false, true, true, nil, @user, @options)


      bp4_subscriptions = get_subscriptions(bp4.bundle_id, @options)
      bp4 = bp4_subscriptions.find { |s| s.subscription_id == bp4.subscription_id }

      events = [{:type                    => 'START_ENTITLEMENT',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => false,
                 :is_blocked_entitlement => false,
                 :service_name           => 'entitlement-service',
                 :service_state_name     => 'ENT_STARTED'},
                {:type                   => 'START_BILLING',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => false,
                 :is_blocked_entitlement => false,
                 :service_name           => 'billing-service',
                 :service_state_name     => 'START_BILLING'},
                {:type                   => 'PAUSE_ENTITLEMENT',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => true,
                 :is_blocked_entitlement => true,
                 :service_name           => 'ServiceStateService',
                 :service_state_name     => 'STATE4a'},
                {:type                   => 'PAUSE_BILLING',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => true,
                 :is_blocked_entitlement => true,
                 :service_name           => 'ServiceStateService',
                 :service_state_name     => 'STATE4a'},
                {:type                   => 'SERVICE_STATE_CHANGE',
                 :date                   => '2012-08-01',
                 :billing_period         => 'MONTHLY',
                 :product                => 'Basic',
                 :plan                   => 'basic-monthly',
                 :phase                  => 'basic-monthly-evergreen',
                 :price_list             => 'DEFAULT',
                 :is_blocked_billing     => true,
                 :is_blocked_entitlement => true,
                 :service_name           => 'ServiceStateService',
                 :service_state_name     => 'STATE4b'}]

      check_events(events, bp4.events)
    end

    def test_cannot_add_ao_if_bundle_block_change
      bp = setup_bp

      # Block change the bundle
      set_bundle_blocking_state(bp.bundle_id, 'STATE1', 'ServiceStateService', true, false, false, nil, @user, @options)

      begin
        create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
        assert(false, "Shouldn't be able to add add-on")
      rescue KillBillClient::API::BadRequest => e
        check_error_message("The action Change is block on this Subscription with id=#{bp.subscription_id}", e)
      end

      check_bp_no_ao(bp)
    end

    def test_cannot_add_ao_if_bundle_block_entitlement
      bp = setup_bp

      # Block entitlement the bundle
      set_bundle_blocking_state(bp.bundle_id, 'STATE1', 'ServiceStateService', false, true, false, nil, @user, @options)

      begin
        create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
        assert(false, "Shouldn't be able to add add-on")
      rescue KillBillClient::API::BadRequest => e
        check_error_message("The action Entitlement is block on this Subscription with id=#{bp.subscription_id}", e)
      end

      check_bp_no_ao(bp)
    end

    def test_can_add_ao_if_bundle_block_billing
      bp = setup_bp

      # Block billing the bundle
      set_bundle_blocking_state(bp.bundle_id, 'STATE1', 'ServiceStateService', false, false, true, nil, @user, @options)

      ao_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      # Bundle blocked billing: only one invoice
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      check_bp_with_ao(bp, ao_entitlement)
    end

    def test_cannot_add_ao_if_bp_block_change
      bp = setup_bp

      # Block change the bundle
      set_subscription_blocking_state(bp.subscription_id, 'STATE1', 'ServiceStateService', true, false, false, nil, @user, @options)

      begin
        create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
        assert(false, "Shouldn't be able to add add-on")
      rescue KillBillClient::API::BadRequest => e
        check_error_message("The action Change is block on this Subscription with id=#{bp.subscription_id}", e)
      end

      check_bp_no_ao(bp)
    end

    def test_cannot_add_ao_if_bp_block_entitlement
      bp = setup_bp

      # Block entitlement the bundle
      set_subscription_blocking_state(bp.subscription_id, 'STATE1', 'ServiceStateService', false, true, false, nil, @user, @options)

      begin
        create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
        assert(false, "Shouldn't be able to add add-on")
      rescue KillBillClient::API::BadRequest => e
        check_error_message("The action Entitlement is block on this Subscription with id=#{bp.subscription_id}", e)
      end

      check_bp_no_ao(bp)
    end

    def test_can_add_ao_if_bp_block_billing
      bp = setup_bp

      # Block entitlement the bundle
      set_subscription_blocking_state(bp.subscription_id, 'STATE1', 'ServiceStateService', false, false, true, nil, @user, @options)

      ao_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      check_bp_with_ao(bp, ao_entitlement)
    end

    def test_can_add_second_ao_if_first_ao_block_change
      bp = setup_bp

      ao1_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Block change the AO
      set_subscription_blocking_state(ao1_entitlement.subscription_id, 'STATE1', 'ServiceStateService', true, false, false, nil, @user, @options)

      ao2_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao2_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      check_bp_with_ao(bp, ao1_entitlement, ao2_entitlement)
    end

    def test_can_add_second_ao_if_first_ao_block_entitlement
      bp = setup_bp

      ao1_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Block entitlement the AO
      set_subscription_blocking_state(ao1_entitlement.subscription_id, 'STATE1', 'ServiceStateService', false, true, false, nil, @user, @options)

      ao2_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao2_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      check_bp_with_ao(bp, ao1_entitlement, ao2_entitlement)
    end

    def test_can_add_second_ao_if_first_ao_block_billing
      bp = setup_bp

      ao1_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      # Block billing the AO
      set_subscription_blocking_state(ao1_entitlement.subscription_id, 'STATE1', 'ServiceStateService', false, false, true, nil, @user, @options)

      ao2_entitlement = create_entitlement_ao(@account.account_id, bp.bundle_id, 'RemoteControl', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao2_entitlement, 'RemoteControl', 'ADD_ON', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      check_bp_with_ao(bp, ao1_entitlement, ao2_entitlement)
    end

    private

    def setup_bp
      kb_clock_set(DEFAULT_KB_INIT_DATE, nil, @options)

      upload_catalog('ReducedSpyCarAdvancedWithThreePhasesAddOns.xml', false, @user, @options)

      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', '2013-08-01', nil)

      bp
    end

    def check_bp_no_ao(bp)
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(1, subscriptions.size)
    end

    def check_bp_with_ao(bp, ao1_entitlement, ao2_entitlement=nil)
      expected_nb_subscriptions = ao2_entitlement.nil? ? 2 : 3

      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(expected_nb_subscriptions, subscriptions.size)

      bps = subscriptions.reject { |s| s.product_category == 'ADD_ON' }
      assert_not_nil(bps)
      assert_equal(1, bps.size)
      assert_equal(bp.subscription_id, bps[0].subscription_id)

      aos = subscriptions.reject { |s| s.product_category == 'BASE' }
      assert_not_nil(aos)
      assert_equal(expected_nb_subscriptions - 1, aos.size)
      if ao2_entitlement.nil?
        assert_equal(ao1_entitlement.subscription_id, aos[0].subscription_id)
      else
        assert_equal(Set.new([ao1_entitlement.subscription_id, ao2_entitlement.subscription_id]),
                     Set.new([aos[0].subscription_id, aos[1].subscription_id]))
      end
    end
  end
end

