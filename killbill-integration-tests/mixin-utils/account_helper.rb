module KillBillIntegrationTests
  module AccountHelper

    def get_account(account_id, with_balance = false, with_balance_and_cba = false, options)
      KillBillClient::Model::Account.find_by_id(account_id, with_balance, with_balance_and_cba, options)
    end

    def create_account(user, time_zone, options)
      external_key = Time.now.to_i.to_s + "-" + rand(1000000).to_s
      account = KillBillClient::Model::Account.new
      account.name = 'KillBillClient'
      account.external_key = external_key
      account.email = 'kill@bill.com'
      account.currency = 'USD'
      account.time_zone = time_zone.nil? ? 'UTC' : time_zone
      account.address1 = '7, yoyo road'
      account.address2 = 'Apt 5'
      account.postal_code = 10293
      account.company = 'Unemployed'
      account.city = 'Foo'
      account.state = 'California'
      account.country = 'LalaLand'
      account.locale = 'fr_FR'
      account.is_notified_for_invoices = false
      assert_nil(account.account_id)

      account = account.create(user, nil, nil, options)
      assert_not_nil(account)
      assert_not_nil(account.account_id)
      account
    end

    def create_account_with_data(user, data, options)
      account = KillBillClient::Model::Account.new
      account.name = data[:name]
      account.external_key = data[:external_key]
      account.email = data[:email]
      account.currency = data[:currency]
      account.time_zone = data[:time_zone]
      account.address1 = data[:address1]
      account.address2 = data[:address2]
      account.postal_code = data[:postal_code]
      account.company = data[:company]
      account.city = data[:city]
      account.state = data[:state]
      account.country = data[:country]
      account.locale = data[:locale]
      account.is_notified_for_invoices = false
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
