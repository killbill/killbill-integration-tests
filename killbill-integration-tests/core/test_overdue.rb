$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestOverdue < Base

    def setup
      @user = 'Overdue'
      setup_base(@user)

      # Create a second tenant
      @options2              = {:username => 'admin', :password => 'password'}
      tenant                 = setup_create_tenant(@user, @options2)
      @options2[:api_key]    = tenant.api_key
      @options2[:api_secret] = tenant.api_secret

      upload_overdue('Overdue.xml', @user, @options)
      upload_overdue('Overdue-v1.xml', @user, @options2)

      @account  = create_account(@user, nil, @options)
      @account2 = create_account(@user, nil, @options2)
    end

    def teardown
      teardown_base
    end

    def test_add_overdue_state
      go_through_all_overdue_stages(@account, 'OD3')

      upload_overdue('Overdue-v1.xml', @user, @options)

      other_account = create_account(@user, nil, @options)
      go_through_all_overdue_stages(other_account, 'OD4', '2013-10-31')
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
      wait_for_expected_clause(1, account) do |account|
        account.invoices(false, options).size
      end

      # Move out of trial
      kb_clock_add_days(31, nil, options)
      wait_for_expected_clause(2, account) do |account|
        account.invoices(false, options).size
      end
      # Move to first overdue stage
      add_days_and_check_overdue_stage(account, 30, 'OD1', options)

      2.upto(3) do |i|
        add_days_and_check_overdue_stage(account, 10, 'OD' + i.to_s, options)
      end

      # Move to last overdue stage
      add_days_and_check_overdue_stage(account, 10, expected_last_stage, options)
    end

    def add_days_and_check_overdue_stage(account, days, stage, options=@options)
      kb_clock_add_days(days, nil, options)
      # Make sure overdue state gets re-computed
      wait_for_killbill
      check_overdue_stage(account, stage, options)
    end

    def check_overdue_stage(account, stage, options=@options)
      overdue_result = account.overdue(options)
      assert_equal(stage, overdue_result.name, 'Failed to retrieve overdue status associated with account')
    end
  end
end
