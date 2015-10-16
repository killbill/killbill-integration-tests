$LOAD_PATH.unshift File.expand_path('../..', __FILE__)
$LOAD_PATH.unshift File.expand_path('..', __FILE__)

require 'seed_base'

module KillBillIntegrationSeed

  class TestSubscriptionAlignment < TestSeedBase

    def setup
      @init_clock = '2013-02-08T01:00:00.000Z'
      setup_seed_base(@init_clock)
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
      @brianking = create_account_with_data(@user, data, @options)
      add_payment_method(@brianking.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      # Generate first invoice
      base = create_entitlement_base(@brianking.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      kb_clock_add_days(5, nil, @options)  # 02/13/2013

      # generate second invoice : OilSlick 2013-02-13 ->  2013-03-08 (bundle aligned so computes until next PHASE event)
      ao1 = create_entitlement_ao(@brianking.account_id, base.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_killbill(@options)

      # generate thid invoice : OilSlick 2013-03-08 ->  2013-03-10 (Recurring phase and BILLING aligned so invoice up to BCD)
      kb_clock_add_days(23, nil, @options)  # 03/08/2013

      # Move after BP trial
      # generate third invoice
      # - BP : 2013-03-13 ->  2013-04-10
      # - Oil Slick 2013-03-10 -> 2013-04-10
      kb_clock_add_days(2, nil, @options)   # 03/10/2013


      kb_clock_add_days(3, nil, @options)   # 03/14/2013

      base.cancel(@user, nil, nil, nil, 'IMMEDIATE', 'END_OF_TERM', nil, @options)
    end

  end
end
