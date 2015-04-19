$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestPaymentWithControl < Base

    def setup

      @user = "PaymentWithControl"
      setup_base(@user)

      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, 'killbill-payment-test', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)

      # Reset with empty array
      @options[:pluginProperty] = []
    end

    def teardown
      teardown_base
    end

    def test_authorize_success
      authorize = 'AUTHORIZE'
      success   = 'SUCCESS'
      payment_key      = 'payment-' + rand(1000000).to_s
      payment_currency = 'USD'

      add_property('TEST_MODE', 'CONTROL')

      auth1_key         = payment_key + '-auth'
      auth1_amount      = '762.99'
      auth1             = create_auth(@account.account_id, payment_key, auth1_key, auth1_amount, payment_currency, @user, @options)
      check_transaction(auth1, payment_key, auth1_key, authorize, auth1_amount, payment_currency, success)
    end

    # The plugin will throw a RuntimeException. Current behavior is to throw 500, so test verifies that, but should we really throw 500? Probably not...
    def test_authorize_plugin_exception
      payment_key = 'payment1-' + rand(1000000).to_s
      payment_currency = 'USD'

      add_property('TEST_MODE', 'CONTROL')
      add_property('THROW_EXCEPTION', 'unknown')

      auth1_key = payment_key + '-auth1'
      auth1_amount = '240922.1504832'
      got_exception = false
      begin
        create_auth(@account.account_id, payment_key, auth1_key, auth1_amount, payment_currency, @user, @options)
        assert(false, "Called was supposed to fail")
      rescue KillBillClient::API::InternalServerError => e
        got_exception= true
      end
      assert(got_exception, "Failed to get exception")
    end

   # Requires KB to be started with org.killbill.payment.plugin.timeout=5s
    def test_authorize_plugin_timedout
      payment_key = 'payment2-' + rand(1000000).to_s
      payment_currency = 'USD'

      add_property('TEST_MODE', 'CONTROL')
      add_property('SLEEP_TIME_SEC', '6.0')

      auth1_key = payment_key + '-auth'
      auth1_amount = '123.5'
      got_exception = false

      auth = create_auth(@account.account_id, payment_key, auth1_key, auth1_amount, payment_currency, @user, @options)
      # 202 in case of timeout
      assert_equal(202, auth.response.code.to_i)
    end

    def test_authorize_with_nil_result
      payment_key      = 'payment3-' + rand(1000000).to_s
      payment_currency = 'USD'

      add_property('TEST_MODE', 'CONTROL')
      add_property('RETURN_NIL', 'foo')

      auth1_key         = payment_key + '-auth1'
      auth1_amount      = '13.23'
      got_exception= false
      begin
        create_auth(@account.account_id, payment_key, auth1_key, auth1_amount, payment_currency, @user, @options)
      rescue KillBillClient::API::InternalServerError => e
        got_exception= true
      end
      assert(got_exception, "Failed to get exception")
    end

    private

    def add_property(key, value)
      prop_test_mode = KillBillClient::Model::PluginPropertyAttributes.new
      prop_test_mode.key = key
      prop_test_mode.value = value
      @options[:pluginProperty] << prop_test_mode
    end

  end
end
