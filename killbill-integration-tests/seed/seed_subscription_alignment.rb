$LOAD_PATH.unshift File.expand_path('../..', __FILE__)
$LOAD_PATH.unshift File.expand_path('..', __FILE__)

require 'seed_base'

module KillBillIntegrationSeed

  class TestSubscriptionAlignment < TestSeedBase

    def setup
      setup_seed_base
    end

    def teardown
      teardown_base
    end


    def test_seed_subscriptions_alignment

      data = {}
      data[:name] = 'Mathew Brown'
      data[:external_key] = 'mathewbrown'
      data[:email] = 'mathewbrown@kb.com'
      data[:currency] = 'GBP'
      data[:time_zone] = 'Europe/London'
      data[:address1] = '5 Downing street'
      data[:address2] = nil
      data[:postal_code] = 'E11 8QS'
      data[:company] = nil
      data[:city] = 'London'
      data[:state] = 'Greater London'
      data[:country] = 'England'
      data[:locale] = 'en_GB'

      @mathewbrown = create_account_with_data(@user, data, @options)
      add_payment_method(@mathewbrown.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      base = create_entitlement_base(@mathewbrown.account_id, 'reserved-vm', 'MONTHLY', 'TRIAL', @user, @options)
      wait_for_expected_clause(1, @mathewbrown, @options, &@proc_account_invoices_nb)

      kb_clock_add_days(5, nil, @options)  # 2015-08-06
      ao1 = create_entitlement_ao(@mathewbrown.account_id, base.bundle_id, 'backup-daily', 'MONTHLY', 'TRIAL', @user, @options)
      wait_for_expected_clause(2, @mathewbrown, @options, &@proc_account_invoices_nb)

      # Generate first non invoice
      kb_clock_add_days(9, nil, @options)  # 2015-08-15
      wait_for_expected_clause(3, @mathewbrown, @options, &@proc_account_invoices_nb)

      kb_clock_add_days(31, nil, @options)  # 2015-09-15
      wait_for_expected_clause(4, @mathewbrown, @options, &@proc_account_invoices_nb)


    end

  end
end
