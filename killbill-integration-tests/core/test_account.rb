# encoding: utf-8

$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestAccountTest < Base

    def setup
      setup_base
    end

    def teardown
      teardown_base
    end

    def test_account_update

      original_account = create_account(@user, @options)

      # Copy original account
      account_data = KillBillClient::Model::Account.new
      account_data.account_id = original_account.account_id
      account_data.name = original_account.name
      account_data.first_name_length = original_account.first_name_length
      account_data.external_key = original_account.external_key
      account_data.email = original_account.email
      account_data.currency = original_account.currency
      account_data.parent_account_id = original_account.parent_account_id
      account_data.is_payment_delegated_to_parent = original_account.is_payment_delegated_to_parent
      account_data.payment_method_id = original_account.payment_method_id
      account_data.time_zone = original_account.time_zone
      account_data.address1 = original_account.address1
      account_data.address2 = original_account.address2
      account_data.postal_code = original_account.postal_code
      account_data.company = original_account.company
      account_data.city = original_account.city
      account_data.state = original_account.state
      account_data.country = original_account.country
      account_data.locale = original_account.locale
      account_data.phone = original_account.phone
      account_data.is_notified_for_invoices = original_account.is_notified_for_invoices


      #
      # Add some notes and perform update
      #
      account_data.notes = 'My notes'

      # Update the notes -> should be the only field that changes
      new_account = account_data.update(true, @user, nil, nil, @options)
      assert_equal(new_account.name, original_account.name)
      assert_equal(new_account.first_name_length, original_account.first_name_length)
      assert_equal(new_account.external_key, original_account.external_key)
      assert_equal(new_account.email, original_account.email)
      assert_equal(new_account.currency, original_account.currency)
      assert_equal(new_account.parent_account_id, original_account.parent_account_id)
      assert_equal(new_account.is_payment_delegated_to_parent, original_account.is_payment_delegated_to_parent)
      assert_equal(new_account.payment_method_id, original_account.payment_method_id)
      assert_equal(new_account.time_zone, original_account.time_zone)
      assert_equal(new_account.address1, original_account.address1)
      assert_equal(new_account.address2, original_account.address2)
      assert_equal(new_account.postal_code, original_account.postal_code)
      assert_equal(new_account.company, original_account.company)
      assert_equal(new_account.city, original_account.city)
      assert_equal(new_account.state, original_account.state)
      assert_equal(new_account.country, original_account.country)
      assert_equal(new_account.locale, original_account.locale)
      assert_equal(new_account.phone, original_account.phone)
      assert_equal(new_account.is_notified_for_invoices, original_account.is_notified_for_invoices)
      assert_equal(new_account.notes, 'My notes')
      assert_nil(original_account.notes)


      #
      # RESET notes and perform update
      #
      account_data.notes = nil

      new_account = account_data.update(true, @user, nil, nil, @options)
      assert_equal(new_account.name, original_account.name)
      assert_equal(new_account.first_name_length, original_account.first_name_length)
      assert_equal(new_account.external_key, original_account.external_key)
      assert_equal(new_account.email, original_account.email)
      assert_equal(new_account.currency, original_account.currency)
      assert_equal(new_account.parent_account_id, original_account.parent_account_id)
      assert_equal(new_account.is_payment_delegated_to_parent, original_account.is_payment_delegated_to_parent)
      assert_equal(new_account.payment_method_id, original_account.payment_method_id)
      assert_equal(new_account.time_zone, original_account.time_zone)
      assert_equal(new_account.address1, original_account.address1)
      assert_equal(new_account.address2, original_account.address2)
      assert_equal(new_account.postal_code, original_account.postal_code)
      assert_equal(new_account.company, original_account.company)
      assert_equal(new_account.city, original_account.city)
      assert_equal(new_account.state, original_account.state)
      assert_equal(new_account.country, original_account.country)
      assert_equal(new_account.locale, original_account.locale)
      assert_equal(new_account.phone, original_account.phone)
      assert_equal(new_account.is_notified_for_invoices, original_account.is_notified_for_invoices)
      assert_nil(new_account.notes)

      #
      # Add some notes again using default update api (set all fields to nil except the one we want to SET)
      #
      account_data = KillBillClient::Model::Account.new
      account_data.account_id = original_account.account_id
      account_data.notes = 'My new notes'

      new_account = account_data.update(false, @user, nil, nil, @options)
      assert_equal(new_account.name, original_account.name)
      assert_equal(new_account.first_name_length, original_account.first_name_length)
      assert_equal(new_account.external_key, original_account.external_key)
      assert_equal(new_account.email, original_account.email)
      assert_equal(new_account.currency, original_account.currency)
      assert_equal(new_account.parent_account_id, original_account.parent_account_id)
      assert_equal(new_account.is_payment_delegated_to_parent, original_account.is_payment_delegated_to_parent)
      assert_equal(new_account.payment_method_id, original_account.payment_method_id)
      assert_equal(new_account.time_zone, original_account.time_zone)
      assert_equal(new_account.address1, original_account.address1)
      assert_equal(new_account.address2, original_account.address2)
      assert_equal(new_account.postal_code, original_account.postal_code)
      assert_equal(new_account.company, original_account.company)
      assert_equal(new_account.city, original_account.city)
      assert_equal(new_account.state, original_account.state)
      assert_equal(new_account.country, original_account.country)
      assert_equal(new_account.locale, original_account.locale)
      assert_equal(new_account.phone, original_account.phone)
      assert_equal(new_account.is_notified_for_invoices, original_account.is_notified_for_invoices)
      assert_equal(new_account.notes, 'My new notes')

    end

  end
end
