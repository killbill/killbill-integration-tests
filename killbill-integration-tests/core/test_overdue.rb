$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestOverdue < Base

    def setup
      @user = 'Overdue'
      setup_base(@user)

      upload_overdue('Overdue.xml', @user, @options)

      @account  = create_account(@user, nil, @options)
      @account2 = create_account(@user, nil, @options)
    end

    def teardown
      teardown_base
    end

    def test_add_overdue_state
      go_through_all_overdue_stages(@account, 'OD3')

      upload_overdue('Overdue-v1.xml', @user, @options)

      go_through_all_overdue_stages(@account2, 'OD4', '2013-10-31')
    end

    private

    def go_through_all_overdue_stages(account, expected_last_stage, start_date=DEFAULT_KB_INIT_DATE)
      bp = create_entitlement_base(account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', start_date, nil)
      wait_for_expected_clause(1, account, &@proc_account_invoices_nb)

      # Move out of trial
      kb_clock_add_days(31, nil, @options)
      wait_for_expected_clause(2, account, &@proc_account_invoices_nb)

      # Move to first overdue stage
      add_days_and_check_overdue_stage(account, 30, 'OD1')

      2.upto(3) do |i|
        add_days_and_check_overdue_stage(account, 10, 'OD' + i.to_s)
      end

      # Move to last overdue stage
      add_days_and_check_overdue_stage(account, 10, expected_last_stage)
    end

    def add_days_and_check_overdue_stage(account, days, stage)
      kb_clock_add_days(days, nil, @options)
      # Make sure overdue state gets re-computed
      wait_for_killbill
      check_overdue_stage(account, stage)
    end

    def check_overdue_stage(account, stage)
      overdue_result = account.overdue(@options)
      assert_equal(stage, overdue_result.name, 'Failed to retrieve overdue status associated with account')
    end
  end
end
