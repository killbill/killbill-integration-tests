$LOAD_PATH.unshift File.expand_path('../..', __FILE__)
$LOAD_PATH.unshift File.expand_path('..', __FILE__)

require 'seed_base'

module KillBillIntegrationSeed

  class TestBillingAlignment < TestSeedBase

    def setup
      setup_seed_base
    end


    def teardown
      teardown_base
    end


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
      base1 = create_entitlement_base(@pierrequiroule.account_id, 'reserved-metal', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @pierrequiroule, @options, &@proc_account_invoices_nb)

      kb_clock_add_days(5 , nil, @options)  # 2015-08-06
      base2 = create_entitlement_base(@pierrequiroule.account_id, 'reserved-metal', 'ANNUAL', 'DEFAULT', @user, @options)
      wait_for_expected_clause(2, @pierrequiroule, @options, &@proc_account_invoices_nb)

      # Generate second invoice for monthly
      kb_clock_add_days(26, nil, @options)  # 2015-09-01


      base1.cancel(@user, nil, nil, nil, 'IMMEDIATE', 'END_OF_TERM', nil, @options)
      base2.cancel(@user, nil, nil, nil, 'IMMEDIATE', 'END_OF_TERM', nil, @options)

    end

  end
end