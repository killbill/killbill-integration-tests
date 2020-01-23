$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestTenant < Base

    def setup
      setup_base

      # Create a second tenant
      @options2              = {:username => 'admin', :password => 'password'}
      tenant                 = setup_create_tenant(@user, @options2)
      @options2[:api_key]    = tenant.api_key
      @options2[:api_secret] = tenant.api_secret

      upload_catalog('Catalog-v1.xml', false, @user, @options)
      upload_catalog('Catalog-v2.xml', false, @user, @options2)

      @account  = create_account(@user, @options)
      @account2 = create_account(@user, @options2)
    end

    def teardown
      teardown_base
    end


    def test_plugin_config
      plugin_name = 'PLUGIN_XXX'
      result = upload_plugin_config(plugin_name, 'plugin.yml', @user, @options2)
      assert_equal('PLUGIN_CONFIG_PLUGIN_XXX', result.key)
      assert_equal(1, result.values.size)

      result = get_plugin_config(plugin_name, @options2)
      assert_equal('PLUGIN_CONFIG_PLUGIN_XXX', result.key)
      assert_equal(1, result.values.size)

      delete_plugin_config(plugin_name, @user, @options2)
      result = get_plugin_config(plugin_name, @options2)
      assert_equal('PLUGIN_CONFIG_PLUGIN_XXX', result.key)
      assert_equal(0, result.values.size)

    end

    def test_cross_tenants_operations
      check_clean_accounts

      handle_server_error { create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options2) }
      check_clean_accounts

      handle_server_error { create_entitlement_base(@account2.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options) }
      check_clean_accounts

      handle_server_error { create_charge(@account.account_id, 7.0, 'USD', 'My first charge', @user, @options2) }
      check_clean_accounts

      handle_server_error { create_charge(@account2.account_id, 7.0, 'USD', 'My first charge', @user, @options) }
      check_clean_accounts

      handle_server_error { create_auth(@account.account_id, 'key', 'key', 7.0, 'USD', @user, @options2) }
      check_clean_accounts

      handle_server_error { create_auth(@account2.account_id, 'key', 'key', 7.0, 'USD', @user, @options) }
      check_clean_accounts

      kb_clock_add_days(60, nil, @options)

      check_clean_accounts
    end

    private

    def handle_server_error
      yield
      assert false
    rescue KillBillClient::API::InternalServerError
    rescue KillBillClient::API::NotFound
    end

    def check_clean_accounts
      check_clean_account(@account, @options)
      check_clean_account(@account2, @options2)
    end

    def check_clean_account(account, options)
      assert_equal(0, account.bundles(options).size)
      assert_equal(0, account.invoices(options).size)
      assert_equal(0, account.payments(options).size)
    end
  end

end
