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

    TIMEOUT_SEC = 120

    DETAIL_MODE = :DETAIL
    AGGREGATE_MODE = :AGGREGATE
    USAGE_DETAIL_MODE_KEY = 'org.killbill.invoice.item.result.behavior.mode'.freeze
    PER_TENANT_CONFIG = 'PER_TENANT_CONFIG'

    def check_error_message(expected, e)
      assert_not_nil(e)
      assert_not_nil(e.message)
      assert_equal(expected, JSON.parse(e.message)['message'])
    end

    def get_resource_as_string(resource_name)
      resource_path_name = File.expand_path("../../resources/#{resource_name}", __FILE__)
      if !File.exist?(resource_path_name) || !File.file?(resource_path_name)
        raise ArgumentError.new("Cannot find resource #{resource_name}")
      end

      resource_file = File.open(resource_path_name, "rb")
      resource_content = resource_file.read
      resource_content
    end

    def get_tenant_catalog(requested_date, options)
      KillBillClient::Model::Catalog.get_tenant_catalog_json(requested_date, options)
    end

    def upload_catalog(name, check_if_exists, user, options)
      proceed_with_upload = !check_if_exists
      if check_if_exists
        res = KillBillClient::Model::Tenant.get_tenant_user_key_value('CATALOG', options)
        proceed_with_upload = res.values.empty?
      end

      if proceed_with_upload
        catalog_file_xml = get_resource_as_string(name)
        KillBillClient::Model::Catalog.upload_tenant_catalog(catalog_file_xml, user, 'New Catalog Version', 'Upload catalog for tenant', options)
      end
    end

    def add_catalog_simple_plan(plan_id, product_name, product_category, currency, amount, billing_period, trial_length, trial_time_unit, user, options)
      simple_plan = KillBillClient::Model::SimplePlanAttributes.new
      simple_plan.plan_id = plan_id
      simple_plan.product_name = product_name
      simple_plan.product_category = product_category
      simple_plan.currency = currency
      simple_plan.amount = amount
      simple_plan.billing_period = billing_period
      simple_plan.trial_length = trial_length
      simple_plan.trial_time_unit = trial_time_unit

      KillBillClient::Model::Catalog.add_tenant_catalog_simple_plan(simple_plan, user, 'Test', 'Upload simple plan', options)
    end

    def upload_tenant_user_key_value(key, value, user, options)
      KillBillClient::Model::Tenant.upload_tenant_user_key_value(key,value, user, 'New Config', 'Upload config for tenant', options)
    end

    def get_tenant_user_key_value(key, options)
      KillBillClient::Model::Tenant.get_tenant_user_key_value(key, options)
    end

    def upload_plugin_config(plugin_name, plugin_config_name, user, options)
      plugin_config = get_resource_as_string(plugin_config_name)
      KillBillClient::Model::Tenant.upload_tenant_plugin_config(plugin_name, plugin_config, user, 'New Plugin Config', 'Upload plugin config for tenant', options)
    end

    def delete_plugin_config(plugin_name, user, options)
      KillBillClient::Model::Tenant.delete_tenant_plugin_config(plugin_name, user, 'New Plugin Config', 'Upload plugin config for tenant', options)
    end

    def get_plugin_config(plugin_name, options)
      KillBillClient::Model::Tenant.get_tenant_plugin_config(plugin_name, options)
    end

    def upload_overdue(name, user, options)
      overdue_file_xml = get_resource_as_string(name)
      KillBillClient::Model::Overdue.upload_tenant_overdue_config_xml(overdue_file_xml, user, 'New Overdue Config Version', 'Upload overdue config for tenant', options)
    end

    def get_tenant_overdue(options)
      KillBillClient::Model::Overdue.get_tenant_overdue_config_json(options)
    end

    def setup_create_tenant(user, options)
      tenant = KillBillClient::Model::Tenant.new
      tenant.external_key = Time.now.to_i.to_s + "-" + rand(1000000).to_s
      tenant.api_key = 'test-api-key' + tenant.external_key
      secret_key = 'test-api-secret' + tenant.external_key
      tenant.api_secret = secret_key

      tenant = tenant.create(true, user, nil, nil, options)
      assert_not_nil(tenant)
      assert_not_nil(tenant.tenant_id)
      # Set the secret key again before returning as this is not returned by the server
      tenant.api_secret = secret_key
      tenant
    end

    def create_tenant_if_does_not_exist(external_key, api_key, api_secret, user, options)
      begin
        tenant = KillBillClient::Model::Tenant.find_by_api_key(api_key, options)
        tenant.api_secret = api_secret
        return
      rescue KillBillClient::API::Unauthorized
      end


      tenant = KillBillClient::Model::Tenant.new
      tenant.external_key = external_key
      tenant.api_key = api_key
      tenant.api_secret = api_secret

      tenant = tenant.create(true, user, nil, nil, options)
      assert_not_nil(tenant)
      assert_not_nil(tenant.tenant_id)
      # Set the secret key again before returning as this is not returned by the server
      tenant.api_secret = api_secret
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
      params                 = {}
      params[:requestedDate] = requested_date unless requested_date.nil?
      params[:timeZone]      = time_zone unless time_zone.nil?

      # The default is not always enough
      params[:timeoutSec]    = options[:timeout_sec] || TIMEOUT_SEC

      res = KillBillClient::API.post "#{KillBillClient::Model::Resource::KILLBILL_API_PREFIX}/test/clock",
                                     {},
                                     params,
                                     {
                                       :read_timeout => (params[:timeoutSec] + 1) * 1000
                                     }.merge(options)
      wait_for_killbill(options)

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

    def wait_for_killbill(options, params = {})
      # The default is not always enough
      params[:timeoutSec] ||= TIMEOUT_SEC

      res = KillBillClient::API.get "#{KillBillClient::Model::Resource::KILLBILL_API_PREFIX}/test/queues",
                                    params,
                                    {
                                    }.merge(options)
    ensure
      assert(!res.nil? && res.code.to_i == 200, 'wait_for_killbill: timed out (events still need to be processed)')
    end

    #
    # Pass a block the will be evaluated until either we match expected value or we timeout
    #
    def wait_for_expected_clause(expected, args, options)
      begin
        Timeout::timeout(TIMEOUT_SEC) do
          while true do
            actual = yield(args)
            return if actual == expected
            wait_for_killbill(options)
          end
        end
      rescue Timeout::Error
        obj_name = args.class.name.split('::').pop.downcase
        obj_id = args.send "#{obj_name}_id".to_sym

        actual = yield(args)
        assert_equal(expected, actual, "wait_for_expected_clause : timed out for #{obj_name} #{obj_id} after #{TIMEOUT_SEC}")
      end
    end

    private

    def increment_kb_clock(days, weeks, months, years, time_zone, options)
      params              = {}
      params[:days]       = days unless days.nil?
      params[:weeks]      = weeks unless weeks.nil?
      params[:months]     = months unless months.nil?
      params[:years]      = years unless years.nil?
      params[:timeZone]   = time_zone unless time_zone.nil?

      # The default is not always enough
      params[:timeoutSec] = options[:timeout_sec] || TIMEOUT_SEC

      res = KillBillClient::API.put "#{KillBillClient::Model::Resource::KILLBILL_API_PREFIX}/test/clock",
                                    {},
                                    params,
                                    {
                                    }.merge(options)
      wait_for_killbill(options)

      JSON.parse res.body
    end
  end
end
