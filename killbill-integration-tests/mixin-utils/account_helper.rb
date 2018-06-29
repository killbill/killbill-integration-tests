module KillBillIntegrationTests
  module AccountHelper

    def get_account(account_id, with_balance = false, with_balance_and_cba = false, options)
      KillBillClient::Model::Account.find_by_id(account_id, with_balance, with_balance_and_cba, options)
    end

    def create_account(user, options)
      create_account_with_data(user, {}, options)
    end

    def close_account(account_id, user, options)
      account = KillBillClient::Model::Account.new
      account.account_id = account_id
      account.close(true, true,  false, user, nil, 'Closing account', options)
    end


    def create_account_with_data(user, data, options)
      account = KillBillClient::Model::Account.new
      account.name = data[:name].nil? ? 'KillBillClient' : data[:name]
      account.first_name_length = data[:first_name_length]
      account.external_key = data[:external_key].nil? ? (Time.now.to_i.to_s + "-" + rand(1000000).to_s) : data[:external_key]
      account.email = data[:email].nil? ? 'kill@bill.com' : data[:email]
      account.bill_cycle_day_local = data[:bill_cycle_day_local]
      account.currency = data[:currency].nil? ? 'USD' : data[:currency]
      account.parent_account_id = data[:parent_account_id] if data[:parent_account_id]
      account.is_payment_delegated_to_parent = data[:is_payment_delegated_to_parent] if !data[:is_payment_delegated_to_parent].nil?
      account.time_zone = data[:time_zone].nil? ? 'UTC' : data[:time_zone]
      account.address1 = data[:address1].nil? ? '7, yoyo road' : data[:address1]
      account.address2 = data[:address2].nil? ? 'Apt 5'  : data[:address2]
      account.postal_code = data[:postal_code].nil? ? 94105 : data[:postal_code]
      account.company = data[:company].nil? ? 'Unemployed' : data[:company]
      account.city = data[:city].nil? ? 'San Francisco' : data[:city]
      account.state = data[:state].nil? ? 'California' : data[:state]
      account.country = data[:country].nil? ? 'US' : data[:country]
      account.locale = data[:locale].nil? ? 'fr_FR' : data[:locale]
      account.phone = data[:phone]
      assert_nil(account.account_id)

      account = account.create(user, nil, nil, options)
      assert_not_nil(account)
      assert_not_nil(account.account_id)
      account
    end

    def get_account_timeline(account_id, options)
      KillBillClient::Model::AccountTimeline.find_by_account_id(account_id, 'MINIMAL', options)
    end


  end
end
