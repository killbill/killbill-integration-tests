$LOAD_PATH.unshift File.expand_path('../..', __FILE__)
$LOAD_PATH.unshift File.expand_path('..', __FILE__)

require 'seed_base'

module KillBillIntegrationSeed

  class TestSubscriptionWithUsage < TestSeedBase

    def setup
      setup_seed_base
    end

    def teardown
      teardown_base
    end

    def test_subscription_with_pure_usage
      aggregate_mode

      data = {}
      data[:name] = 'James Bond'
      data[:external_key] = 'jamesbond'
      data[:email] = 'jamesbond@kb.com'
      data[:currency] = 'GBP'
      data[:time_zone] = 'Europe/London'
      data[:address1] = '20 Downing street'
      data[:address2] = nil
      data[:postal_code] = 'E11 8QS'
      data[:company] = nil
      data[:city] = 'London'
      data[:state] = 'Greater London'
      data[:country] = 'England'
      data[:locale] = 'en_GB'
      @jamesbond = create_account_with_data(@user, data, @options)
      add_payment_method(@jamesbond.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)




      bp = create_entitlement_base(@jamesbond.account_id, 'on-demand-metal', 'NO_BILLING_PERIOD', 'DEFAULT', @user, @options)

      # 20015-08-05
      kb_clock_add_days(4, nil, @options)
      usage_input = [{:unit_type => 'cpu-hour',
                      :usage_records => [{:record_date => '2015-08-05', :amount => 10}]
                     }]
      record_usage(bp.subscription_id, usage_input, @user, @options)

      # 20015-09-01
      kb_clock_add_days(27, nil, @options)
      wait_for_expected_clause(1, @jamesbond, @options, &@proc_account_invoices_nb)

    end

    def test_recurring_subscription_with_usage

      data = {}
      data[:name] = 'Sean Connery'
      data[:external_key] = 'seanconnery'
      data[:email] = 'seanconnery@kb.com'
      data[:currency] = 'GBP'
      data[:time_zone] = 'Europe/London'
      data[:address1] = '67 Downing street'
      data[:address2] = nil
      data[:postal_code] = 'E11 8QS'
      data[:company] = nil
      data[:city] = 'London'
      data[:state] = 'Greater London'
      data[:country] = 'England'
      data[:locale] = 'en_GB'
      @seanconnery = create_account_with_data(@user, data, @options)
      add_payment_method(@seanconnery.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)


      bp = create_entitlement_base(@seanconnery.account_id, 'reserved-metal', 'ANNUAL', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @seanconnery, @options, &@proc_account_invoices_nb)

      # 20015-08-05
      kb_clock_add_days(4, nil, @options)
      usage_input = [{:unit_type => 'cpu-hour',
                      :usage_records => [{:record_date => '2015-08-05', :amount => 100}]
                     }]
      record_usage(bp.subscription_id, usage_input, @user, @options)

      # 20015-09-01
      kb_clock_add_days(27, nil, @options)
      wait_for_expected_clause(2, @seanconnery, @options, &@proc_account_invoices_nb)


    end


  end
end