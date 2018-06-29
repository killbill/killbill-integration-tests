$LOAD_PATH.unshift File.expand_path('../mixin-utils', __FILE__)
$LOAD_PATH.unshift File.expand_path('../mixin-checkers', __FILE__)

require 'test/unit'
require 'killbill_client'
require 'helper'
require 'checker'
require 'logger'

module KillBillIntegrationTests
  class Base < Test::Unit::TestCase

    include Helper
    include Checker

    DEFAULT_KB_ADDRESS='127.0.0.1'
    DEFAULT_KB_PORT='8080'
    DEFAULT_CATALOG='SpyCarAdvanced.xml'

    DEFAULT_KB_INIT_DATE = "2013-08-01"
    DEFAULT_KB_INIT_CLOCK = "#{DEFAULT_KB_INIT_DATE}T06:00:00.000Z"

    DEFAULT_MULTI_TENANT_INFO = {:use_multi_tenant => true,
                                 :create_multi_tenant => true}

    def setup_base(user=self.method_name, tenant_info=DEFAULT_MULTI_TENANT_INFO, init_clock=DEFAULT_KB_INIT_CLOCK, killbill_address=DEFAULT_KB_ADDRESS, killbill_port=DEFAULT_KB_PORT)
      # make sure this fits into 50 characters
      @user = user.slice(0..45)

      # Default running instance of Kill Bill server
      reset_killbill_client_url(killbill_address, killbill_port)

      if ENV['CIRCLECI']
        setup_logger
        KillBillClient.return_full_stacktraces = true
      end

      # RBAC default options
      @options = {:username => ENV['USERNAME'] || 'admin', :password => ENV['PASSWORD'] || 'password'}

      # Create tenant and provide options for multi-tenants headers(X-Killbill-ApiKey/X-Killbill-ApiSecret)
      if tenant_info[:use_multi_tenant]
        if tenant_info[:create_multi_tenant]
          tenant = setup_create_tenant(@user, @options)
          @options[:api_key] = tenant.api_key
          @options[:api_secret] = tenant.api_secret
        # Reuse mt
        else
          @options[:api_key] = tenant_info[:api_key]
          @options[:api_secret] = tenant_info[:api_secret]
          create_tenant_if_does_not_exist(tenant_info[:external_key], tenant_info[:api_key], tenant_info[:api_secret], @user, @options)
        end

        @account = nil
      end

      kb_clock_set(init_clock, nil, @options)

      # Define the proc that is used to retrieve all accounts on the test account
      @proc_account_invoices_nb = Proc.new do |account|
        account.invoices(false, @options).size
      end
      @proc_invoice_items_nb = Proc.new { |invoice_id| get_invoice_by_id(invoice_id, @options).items.size }
    end

    def reset_killbill_client_url(killbill_address, killbill_port)
      KillBillClient.url = "http://#{killbill_address}:#{killbill_port}"
    end

    def setup_logger
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
      KillBillClient.logger = logger
    end

    def load_default_catalog
      upload_catalog(DEFAULT_CATALOG, true, @user, @options)
    end

    def teardown_base
      close_account(@account.account_id, @user, @options) unless @account.nil?

      # Reset clock to now to avoid lengthy catch-ups later on
      kb_clock_set(nil, nil, @options)

      # TODO cleanup of data with control parameter
    end

    def detail_mode
      usage_detail_mode(DETAIL_MODE)
    end

    def aggregate_mode
      usage_detail_mode(AGGREGATE_MODE)
    end

    def detail_mode?
      !aggregate_mode?
    end

    def aggregate_mode?
      result = get_tenant_user_key_value(PER_TENANT_CONFIG, @options)
      return true if result.values.empty?

      configurations = result.values.reject do |value|
        conf = JSON.parse(value)
        conf[USAGE_DETAIL_MODE_KEY].nil?
      end
      configurations.nil? || configurations[0][USAGE_DETAIL_MODE_KEY] == AGGREGATE_MODE
    end

    def usage_detail_mode(usage_detail_mode_value)
      mode = {}
      mode[USAGE_DETAIL_MODE_KEY] = usage_detail_mode_value
      upload_tenant_user_key_value(PER_TENANT_CONFIG, mode.to_json)
    end

    def upload_tenant_user_key_value(key, value)
      super(key, value, @user, @options)
    end
  end
end

