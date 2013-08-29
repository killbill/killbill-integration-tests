
require 'test_entitlement_util'

module KillBillIntegrationTests
  module TestUtil

    include TestEntitlementUtil

    def setup_create_tenant(user, options)
      tenant = KillBillClient::Model::Tenant.new
      tenant.external_key = Time.now.to_i.to_s
      tenant.api_key = 'test-api-key' + tenant.external_key
      secret_key = 'test-api-secret' + tenant.external_key
      tenant.api_secret = secret_key

      tenant = tenant.create(user, nil, nil, options)
      assert_not_nil(tenant)
      assert_not_nil(tenant.tenant_id)
      # Set the secret key again before returning as this is not returned by the server
      tenant.api_secret = secret_key
      tenant
    end

    def setup_create_account(user, time_zone, options)
      external_key = Time.now.to_i.to_s
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
      account.locale = 'FR_fr'
      account.is_notified_for_invoices = false
      assert_nil(account.account_id)

      account = account.create(user, nil, nil, options)
      assert_not_nil(account)
      assert_not_nil(account.account_id)
      account
    end

    def kb_clock_get(time_zone, options)
      params = {}
      params[:timeZone] = time_zone unless time_zone.nil?

      res = KillBillClient::API.get "#{KillBillClient::Model::Resource::KILLBILL_API_PREFIX}/test/clock",
                                    params,
                                    options
      JSON.parse res.body
    end


    def kb_clock_set(requested_date, time_zone, options)
      params = {}
      params[:requestedDate] = requested_date unless requested_date.nil?
      params[:timeZone] = time_zone unless time_zone.nil?

      res = KillBillClient::API.post "#{KillBillClient::Model::Resource::KILLBILL_API_PREFIX}/test/clock",
                            {},
                            params,
                            {
                            }.merge(options)
      JSON.parse res.body
    end

    def kb_clock_add_days(days, time_zone, options)
      increment_kb_clock(days, nil, nil, nil, time_zone, options)
    end

    def kb_clock_add_weeks(weeks, time_zone, options)
      increment_kb_clock(nil, weeks, nil, nil, time_zone, options)
    end

    def kb_clock_add_months(months, time_zone, options)
      increment_kb_clock(nil, nil, months, nil, time_zone, options)
    end

    def kb_clock_add_years(years, time_zone, options)
      increment_kb_clock(nil, nil, years, nil, time_zone, options)
    end

    private

    def increment_kb_clock(days, weeks, months, years, time_zone, options)
      params = {}
      params[:days] = days unless days.nil?
      params[:weeks] = weeks unless weeks.nil?
      params[:months] = months unless months.nil?
      params[:years] = years unless years.nil?
      params[:timeZone] = time_zone unless time_zone.nil?

      res = KillBillClient::API.put "#{KillBillClient::Model::Resource::KILLBILL_API_PREFIX}/test/clock",
                           {},
                           params,
                           {
                           }.merge(options)

      # TODO we should ensure on the sever side that all bus/notifications have been processed before we return
      # which would avoid that flaky hack
      sleep 3

      JSON.parse res.body
    end


  end
end