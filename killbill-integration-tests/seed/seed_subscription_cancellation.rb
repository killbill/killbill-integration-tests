$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationSeed

  class TestSubscriptionCancellation < KillBillIntegrationTests::Base

    def setup
      @user = "admin"
      @init_clock = '2013-02-08T01:00:00.000Z'
      setup_base(@user, false, @init_clock)

    end

    def teardown
      teardown_base
    end

=begin
=end

    def test_seed_subscriptions_cancellation_imm_eot

      data = {}
      data[:name] = 'Allison Greenwich'
      data[:external_key] = 'allisongreenwich'
      data[:email] = 'allisongreenwich@kb.com'
      data[:currency] = 'GBP'
      data[:time_zone] = 'Europe/London'
      data[:address1] = '10 Downing street'
      data[:address2] = nil
      data[:postal_code] = 'E11 8QS'
      data[:company] = nil
      data[:city] = 'London'
      data[:state] = 'Greater London'
      data[:country] = 'England'
      data[:locale] = 'en_GB'
      @allisongreenwich = create_account_with_data(@user, data, @options)
      add_payment_method(@allisongreenwich.account_id, '__EXTERNAL_PAYMENT__', true, @user, @options)

      # Generate first invoice
      base = create_entitlement_base(@allisongreenwich.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Generate second invoice after trial
      kb_clock_add_days(31, nil, @options)

      # Cancel BP  in trial with no arguments
      requested_date = nil
      entitlement_policy = "IMMEDIATE"
      billing_policy = "END_OF_TERM"
      use_requested_date_for_billing = nil

      base.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)
    end


    def test_seed_subscriptions_cancellation_imm_imm

      data = {}
      data[:name] = 'Christian Lolipop'
      data[:external_key] = 'christianlolipop'
      data[:email] = 'christianlolipop@kb.com'
      data[:currency] = 'GBP'
      data[:time_zone] = 'Europe/London'
      data[:address1] = '17 Downing street'
      data[:address2] = nil
      data[:postal_code] = 'E11 8QS'
      data[:company] = nil
      data[:city] = 'London'
      data[:state] = 'Greater London'
      data[:country] = 'England'
      data[:locale] = 'en_GB'
      @christianlolipop = create_account_with_data(@user, data, @options)
      add_payment_method(@christianlolipop.account_id, '__EXTERNAL_PAYMENT__', true, @user, @options)

      # Generate first invoice
      base = create_entitlement_base(@christianlolipop.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      # Generate second invoice after trial
      kb_clock_add_days(31, nil, @options)

      # Cancel BP  in trial with no arguments
      requested_date = nil
      entitlement_policy = "IMMEDIATE"
      billing_policy = "IMMEDIATE"
      use_requested_date_for_billing = nil

      base.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)
    end

  end
end