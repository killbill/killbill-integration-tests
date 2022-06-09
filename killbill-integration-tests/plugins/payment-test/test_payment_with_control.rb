# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('.', __dir__)

require 'payment_test_base'

module KillBillIntegrationTests
  class TestPaymentWithControl < KillBillIntegrationTests::PaymentTestBase
    def setup
      super

      @user = 'PaymentWithControl'

      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, PLUGIN_NAME, true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)

      # Reset with empty array
      @options[:pluginProperty] = []
    end

    def test_authorize_success
      authorize = 'AUTHORIZE'
      success   = 'SUCCESS'
      payment_key = 'payment-' + rand(1_000_000).to_s
      payment_currency = 'USD'

      auth1_key         = payment_key + '-auth'
      auth1_amount      = '762.99'
      auth1             = create_auth(@account.account_id, payment_key, auth1_key, auth1_amount, payment_currency, @user, @options)
      check_transaction(auth1, payment_key, auth1_key, authorize, auth1_amount, payment_currency, success)
    end

    def test_authorize_plugin_exception
      payment_key = 'payment1-' + rand(1_000_000).to_s
      payment_currency = 'USD'

      body = { 'CONFIGURE_ACTION': 'ACTION_THROW_EXCEPTION' }.to_json
      KillBillClient::API.post(KILLBILL_PAYMENT_TEST_PREFIX + '/configure', body, {}, @options)

      auth1_key = payment_key + '-auth1'
      auth1_amount = '240922.1504832'
      got_exception = false
      begin
        create_auth(@account.account_id, payment_key, auth1_key, auth1_amount, payment_currency, @user, @options)
        assert(false, 'Called was supposed to fail')
      rescue KillBillClient::API::BadRequest
        got_exception = true
      end
      assert(got_exception, 'Failed to get exception')
    end

    # Requires KB to be started with org.killbill.payment.plugin.timeout=5s
    def test_authorize_plugin_timedout
      payment_key = 'payment2-' + rand(1_000_000).to_s
      payment_currency = 'USD'

      body = { 'CONFIGURE_ACTION': 'ACTION_SLEEP', 'SLEEP_TIME_SEC': 6 }.to_json
      KillBillClient::API.post(KILLBILL_PAYMENT_TEST_PREFIX + '/configure', body, {}, @options)

      auth1_key = payment_key + '-auth'
      auth1_amount = '123.5'

      begin
        create_auth(@account.account_id, payment_key, auth1_key, auth1_amount, payment_currency, @user, @options)
        flunk('Call should have timedout')
      rescue KillBillClient::API::GatewayTimeout
        # 504 in case of timeout
      end
    end

    def test_authorize_with_nil_result
      payment_key      = 'payment3-' + rand(1_000_000).to_s
      payment_currency = 'USD'

      body = { 'CONFIGURE_ACTION': 'RETURN_NIL' }.to_json
      KillBillClient::API.post(KILLBILL_PAYMENT_TEST_PREFIX + '/configure', body, {}, @options)

      auth1_key         = payment_key + '-auth1'
      auth1_amount      = '13.23'
      got_exception = false
      begin
        create_auth(@account.account_id, payment_key, auth1_key, auth1_amount, payment_currency, @user, @options)
      rescue KillBillClient::API::InternalServerError
        got_exception = true
      end
      assert(got_exception, 'Failed to get exception')
    end
  end
end
