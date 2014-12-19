require 'timeout'

require 'account_helper'
require 'entitlement_helper'
require 'invoice_helper'
require 'payment_helper'
require 'refund_helper'
require 'usage_helper'


module KillBillIntegrationTests
  module Helper

    include AccountHelper
    include EntitlementHelper
    include InvoiceHelper
    include PaymentHelper
    include RefundHelper
    include UsageHelper

    TIMEOUT_SEC = 5

    def get_resource_as_string(resource_name)
      resource_path_name = File.expand_path("../../resources/#{resource_name}", __FILE__)
      if !File.exists?(resource_path_name) || !File.file?(resource_path_name)
        raise ArgumentError.new("Cannot find resource #{resource_name}")
      end

      resource_file = File.open(resource_path_name, "rb")
      resource_content = resource_file.read
      resource_content
    end

    def setup_create_tenant(user, options)
      tenant = KillBillClient::Model::Tenant.new
      tenant.external_key = Time.now.to_i.to_s + "-" + rand(1000000).to_s
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

    def add_payment_method(account_id, plugin_name, is_default, plugin_info, user, options)
      pm = KillBillClient::Model::PaymentMethod.new
      pm.account_id = account_id
      pm.plugin_name = plugin_name
      pm.plugin_info = plugin_info if plugin_info

      pm.create(is_default, user, nil, nil, options)
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

    def wait_for_killbill
      sleep 3
    end


    #
    # Pass a block the will be evaluated until either we match expected value ort we timeout
    #
    def wait_for_expected_clause(expected, args)


      begin
        Timeout::timeout(TIMEOUT_SEC) do
          while true do
            nb_invoices = yield(args)
            return if nb_invoices == expected
            sleep 1
          end
        end
      rescue Timeout::Error => e
        obj_name = args.class.name.split('::').pop.downcase
        obj_id = args.send "#{obj_name}_id".to_sym
        puts "wait_for_expected_clause : timed out for #{obj_name} #{obj_id} after #{TIMEOUT_SEC}"
      end
    end


    private


    # Add sleep padding -- the server chekx for notificationq when we move the clock but we still don't have gurantees there is
    # no bus events left in the queue
    def increment_kb_clock(days, weeks, months, years, time_zone, options)
      params = {}
      params[:days] = days unless days.nil?
      params[:weeks] = weeks unless weeks.nil?
      params[:months] = months unless months.nil?
      params[:years] = years unless years.nil?
      params[:timeZone] = time_zone unless time_zone.nil?

      ini=Time.now; sleep 3; fini=Time.now;

      res = KillBillClient::API.put "#{KillBillClient::Model::Resource::KILLBILL_API_PREFIX}/test/clock",
                                    {},
                                    params,
                                    {
                                    }.merge(options)

      ini=Time.now; sleep 5; fini=Time.now;
      JSON.parse res.body
    end


  end
end
