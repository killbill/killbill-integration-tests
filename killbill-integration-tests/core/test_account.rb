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
      assert_equal(new_account.notes, 'My new notes')
    end

    def test_account_blocking_state
      account = create_account(@user, @options)

      # Verify account methods
      assert_respond_to(account, :blocking_states)
      assert_respond_to(account, :set_blocking_state)

      # Get blocking states
      blocking_states = account.blocking_states('ACCOUNT', nil, 'NONE', @options)

      # Verify if the returned list is empty
      assert(blocking_states.empty?)

      # Verify if response is success
      # assert(account.set_blocking_state('STATE1', 'ServiceStateService', false, false, false, nil, @user, nil, nil, @options).response .kind_of? Net::HTTPSuccess)
      account.set_blocking_state('STATE1', 'ServiceStateService', false, false, false, nil, @user, nil, nil, @options)

      # Verify if the returned list has now one element
      blocking_states = account.blocking_states('ACCOUNT', nil, 'NONE', @options)
      assert_equal(1, blocking_states.size)

      # Verify blocking state fields
      blocking_states = blocking_states.first
      assert_equal('STATE1', blocking_states.state_name)
      assert_equal('ServiceStateService', blocking_states.service)
      assert_false(blocking_states.is_block_change)
      assert_false(blocking_states.is_block_entitlement)
      assert_false(blocking_states.is_block_billing)
    end

    def test_cba_rebalancing
      account = create_account(@user, @options)

      # Verify if response is success
      assert(account.cba_rebalancing(@user, nil, nil, @options).response.kind_of? Net::HTTPSuccess)
    end

    def test_custom_fields
      account = create_account(@user, @options)

      custom_field = KillBillClient::Model::CustomFieldAttributes.new
      custom_field.name = 'Test Custom Field'
      custom_field.value = 'test_value'
      account.add_custom_field(custom_field, @user, nil, nil, @options)

      custom_field = account.custom_fields('NONE', @options)

      assert_equal('Test Custom Field', custom_field[0].name)
      assert_equal('test_value', custom_field[0].value)

      custom_field[0].value = 'another_test_value'
      account.modify_custom_field(custom_field, @user, nil, nil, @options)

      custom_field = account.custom_fields('NONE', @options)

      assert_equal('Test Custom Field', custom_field[0].name)
      assert_equal('another_test_value', custom_field[0].value)

      custom_field_id = custom_field[0].custom_field_id
      account.remove_custom_field(custom_field_id, @user, nil, nil, @options)

      custom_field = account.custom_fields('NONE', @options)
      assert_empty(custom_field)
    end
  end
end
