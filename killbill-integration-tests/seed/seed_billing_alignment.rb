$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationSeed

  class TestBillingAlignment < KillBillIntegrationTests::Base

    def setup
      @user = "admin"
      @init_clock = '2013-02-08T01:00:00.000Z'
      setup_base(@user, false, @init_clock)

    end

    def teardown
      teardown_base
    end

=begin
    Verify that the invoice for the annual goes to the 15 and the 10 which is the BCD because it is on its own timeline
=end

    def test_seed_billing_alignments

      data = {}
      data[:name] = 'Pierre Quiroule'
      data[:external_key] = 'pierrequiroule'
      data[:email] = 'pierrequiroule@kb.com'
      data[:currency] = 'EUR'
      data[:time_zone] = 'Europe/Paris'
      data[:address1] = '12 rue de la bergere'
      data[:address2] = nil
      data[:postal_code] = '75003'
      data[:company] = nil
      data[:city] = 'Paris'
      data[:state] = 'Region Parisienne'
      data[:country] = 'France'
      data[:locale] = 'fr_FR'

      @pierrequiroule = create_account_with_data(@user, data, @options)
      add_payment_method(@pierrequiroule.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

      # Generate first invoice for the annual plan
      base1 = create_entitlement_base(@pierrequiroule.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)

      kb_clock_add_days(5, nil, @options)  # 02/13/2013
      base2 = create_entitlement_base(@pierrequiroule.account_id, 'Standard', 'ANNUAL', 'DEFAULT', @user, @options)

      # Generate first invoice for monthly  03/10/2013 -> 04/10/2013
      kb_clock_add_days(26, nil, @options)  # 03/11/2013

      # Generate first invoice for annual  03/15/2013 -> 03/15/2014
      kb_clock_add_days(5, nil, @options)  # 03/16/2013

      base1.cancel(@user, nil, nil, nil, 'IMMEDIATE', 'END_OF_TERM', nil, @options)

      base2.cancel(@user, nil, nil, nil, 'IMMEDIATE', 'END_OF_TERM', nil, @options)

    end

  end
end