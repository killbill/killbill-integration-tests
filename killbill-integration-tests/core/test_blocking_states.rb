$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestBlockingStates < Base

    def setup
      setup_base

      catalog_file_xml = get_resource_as_string("Catalog-Simple.xml")
      KillBillClient::Model::Catalog.upload_tenant_catalog(catalog_file_xml, @user, 'New Catalog Version', 'Upload catalog for tenant', @options)

      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

    end

    def teardown
      teardown_base
    end


    def test_service_state_changes

      # Start one year earlier than any other test (because we end up moving the clock by 11 months so we don't want all kinds of parasite account to start kicking it and impacting the timing of our test)
      kb_clock_set('2012-08-01T06:00:00.000Z', nil, @options)

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


  end
end

