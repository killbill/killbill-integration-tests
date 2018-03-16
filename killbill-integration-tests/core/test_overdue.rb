$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestOverdue < Base

    def setup
      setup_base
      load_default_catalog

      # Create a second tenant
      @options2              = {:username => 'admin', :password => 'password'}
      tenant                 = setup_create_tenant(@user, @options2)
      @options2[:api_key]    = tenant.api_key
      @options2[:api_secret] = tenant.api_secret

      upload_overdue('Overdue.xml', @user, @options)
      upload_overdue('Overdue-v1.xml', @user, @options2)

      @account  = create_account(@user, @options)
      @account2 = create_account(@user, @options2)
    end

    def teardown
      close_account(@account2.account_id, @user, @options2)

      teardown_base
    end

    def test_add_overdue_state
      bp = go_through_all_overdue_stages(@account, 'OD3', '2013-08-01')
      check_entitlement_with_events(bp,
                                    '2013-08-01',
                                    [{:type                   => 'START_ENTITLEMENT',
                                      :date                   => '2013-08-01',
                                      :is_blocked_billing     => false,
                                      :is_blocked_entitlement => false,
                                      :service_name           => 'entitlement-service',
                                      :service_state_name     => 'ENT_STARTED'},
                                     {:type                   => 'START_BILLING',
                                      :date                   => '2013-08-01',
                                      :is_blocked_billing     => false,
                                      :is_blocked_entitlement => false,
                                      :service_name           => 'billing-service',
                                      :service_state_name     => 'START_BILLING'},
                                     {:type                   => 'PHASE',
                                      :date                   => '2013-08-31',
                                      :is_blocked_billing     => false,
                                      :is_blocked_entitlement => false,
                                      :service_name           => 'entitlement+billing-service',
                                      :service_state_name     => 'PHASE'},
                                     {:type                   => 'SERVICE_STATE_CHANGE',
                                      :date                   => '2013-10-01',
                                      :is_blocked_billing     => false,
                                      :is_blocked_entitlement => false,
                                      :service_name           => 'overdue-service',
                                      :service_state_name     => 'OD1'},
                                     {:type                   => 'PAUSE_ENTITLEMENT',
                                      :date                   => '2013-10-11',
                                      :is_blocked_billing     => true,
                                      :is_blocked_entitlement => true,
                                      :service_name           => 'overdue-service',
                                      :service_state_name     => 'OD2'},
                                     {:type                   => 'PAUSE_BILLING',
                                      :date                   => '2013-10-11',
                                      :is_blocked_billing     => true,
                                      :is_blocked_entitlement => true,
                                      :service_name           => 'overdue-service',
                                      :service_state_name     => 'OD2'},
                                     {:type                   => 'SERVICE_STATE_CHANGE',
                                      :date                   => '2013-10-21',
                                      :is_blocked_billing     => true,
                                      :is_blocked_entitlement => true,
                                      :service_name           => 'overdue-service',
                                      :service_state_name     => 'OD3'}],
                                    @options)

      upload_overdue('Overdue-v1.xml', @user, @options)

      other_account = create_account(@user, @options)
      bp            = go_through_all_overdue_stages(other_account, 'OD4', '2013-10-31')
      check_entitlement_with_events(bp,
                                    '2013-10-31',
                                    [{:type                   => 'START_ENTITLEMENT',
                                      :date                   => '2013-10-31',
                                      :is_blocked_billing     => false,
                                      :is_blocked_entitlement => false,
                                      :service_name           => 'entitlement-service',
                                      :service_state_name     => 'ENT_STARTED'},
                                     {:type                   => 'START_BILLING',
                                      :date                   => '2013-10-31',
                                      :is_blocked_billing     => false,
                                      :is_blocked_entitlement => false,
                                      :service_name           => 'billing-service',
                                      :service_state_name     => 'START_BILLING'},
                                     {:type                   => 'PHASE',
                                      :date                   => '2013-11-30',
                                      :is_blocked_billing     => false,
                                      :is_blocked_entitlement => false,
                                      :service_name           => 'entitlement+billing-service',
                                      :service_state_name     => 'PHASE'},
                                     {:type                   => 'SERVICE_STATE_CHANGE',
                                      :date                   => '2013-12-31',
                                      :is_blocked_billing     => false,
                                      :is_blocked_entitlement => false,
                                      :service_name           => 'overdue-service',
                                      :service_state_name     => 'OD1'},
                                     {:type                   => 'PAUSE_ENTITLEMENT',
                                      :date                   => '2014-01-10',
                                      :is_blocked_billing     => true,
                                      :is_blocked_entitlement => true,
                                      :service_name           => 'overdue-service',
                                      :service_state_name     => 'OD2'},
                                     {:type                   => 'PAUSE_BILLING',
                                      :date                   => '2014-01-10',
                                      :is_blocked_billing     => true,
                                      :is_blocked_entitlement => true,
                                      :service_name           => 'overdue-service',
                                      :service_state_name     => 'OD2'},
                                     {:type                   => 'SERVICE_STATE_CHANGE',
                                      :date                   => '2014-01-20',
                                      :is_blocked_billing     => true,
                                      :is_blocked_entitlement => true,
                                      :service_name           => 'overdue-service',
                                      :service_state_name     => 'OD3'},
                                     {:type                   => 'SERVICE_STATE_CHANGE',
                                      :date                   => '2014-01-30',
                                      :is_blocked_billing     => true,
                                      :is_blocked_entitlement => true,
                                      :service_name           => 'overdue-service',
                                      :service_state_name     => 'OD4'}],
                                    @options)
    end

    # Similar test than the one above, but rely on the re-evaluation interval
    # to check the new overdue config has been uploaded
    def test_add_overdue_state_and_check_reevaluation_interval
      go_through_all_overdue_stages(@account, 'OD3')

      # Re-evaluation 5 days later
      add_days_and_check_overdue_stage(@account, 5, 'OD3')

      upload_overdue('Overdue-v1.xml', @user, @options)

      # Re-evaluation 5 days later
      add_days_and_check_overdue_stage(@account, 5, 'OD4')
    end

    def test_per_tenant_overdue_config
      go_through_all_overdue_stages(@account, 'OD3')
      go_through_all_overdue_stages(@account2, 'OD4', '2013-10-31', @options2)
    end

    private

    def go_through_all_overdue_stages(account, expected_last_stage, start_date=DEFAULT_KB_INIT_DATE, options=@options)
      bp = create_entitlement_base(account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', start_date, nil)
      wait_for_expected_clause(1, account, options) do |an_account|
        an_account.invoices(false, options).size
      end

      # Move out of trial
      kb_clock_add_days(31, nil, options)
      wait_for_expected_clause(2, account, options) do |an_account|
        an_account.invoices(false, options).size
      end
      # Move to first overdue stage
      add_days_and_check_overdue_stage(account, 30, 'OD1', options)

      2.upto(3) do |i|
        kb_clock_add_days(5, nil, options)
        wait_for_killbill(options)
        add_days_and_check_overdue_stage(account, 5, 'OD' + i.to_s, options)
      end

      # Move to last overdue stage
      kb_clock_add_days(5, nil, options)
      wait_for_killbill(options)
      add_days_and_check_overdue_stage(account, 5, expected_last_stage, options)

      bp
    end

    def check_entitlement_with_events(bp, start_date, events, options)
      subscriptions = get_subscriptions(bp.bundle_id, options)
      assert_equal(1, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', start_date, nil, start_date, nil)
      check_events(events, bp.events)
    end

    def add_days_and_check_overdue_stage(account, days, stage, options=@options)
      kb_clock_add_days(days, nil, options)
      check_overdue_stage(account, stage, options)
    end

    def check_overdue_stage(account, stage, options=@options)
      wait_for_expected_clause(stage, account, options) do |an_account|
        an_account.overdue(options).name
      end
    end
  end
end
