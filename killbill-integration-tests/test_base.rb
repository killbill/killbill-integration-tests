require 'test/unit'
require 'killbill_client'
require 'test_util'

module KillBillIntegrationTests
  class Base < Test::Unit::TestCase

    include TestUtil

    # Default running instance of Kill Bill server
    KillBillClient.url = 'http://127.0.0.1:8080'

    DEFAULT_KB_INIT_DATE = "2013-08-1"
    DEFAULT_KB_INIT_CLOCK = "#{DEFAULT_KB_INIT_DATE}T06:00:00.000Z"

    def setup_base(user)

      # RBAC default options
      @options = {:username => 'admin', :password => 'password'}

      # Create tenant and provide options for multi-tenants headers(X-Killbill-ApiKey/X-Killbill-ApiSecret)
      tenant = setup_create_tenant(user, @options)
      @options[:api_key] = tenant.api_key
      @options[:api_secret] = tenant.api_secret

      kb_clock_set(DEFAULT_KB_INIT_CLOCK, nil, @options)
    end

    def teardown_base
      # TODO cleanup of data with control parameter
    end

  end
end


