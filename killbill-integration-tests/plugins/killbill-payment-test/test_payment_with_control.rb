$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)
$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'plugin_base'

module KillBillIntegrationTests

  class TestPaymentWithControl < KillBillIntegrationTests::PluginBase

    PLUGIN_KEY = "payment-test"
    # Default to latest
    PLUGIN_VERSION = nil


    PLUGIN_PROPS = [{:key => 'pluginArtifactId', :value => 'payment-test-plugin'},
                    {:key => 'pluginGroupId', :value => 'org.kill-bill.billing.plugin.ruby'},
                    {:key => 'pluginType', :value => 'ruby'},
    ]

    def setup
      @user = 'PaymentWithControl'
      setup_plugin_base(DEFAULT_KB_INIT_CLOCK, PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)

      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, 'killbill-payment-test', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)

      # Reset with empty array
      @options[:pluginProperty] = []
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY)
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
      rescue KillBillClient::API::BadRequest => e
        got_exception= true
      end
      assert(got_exception, "Failed to get exception")
    end

    unless ENV['CIRCLECI']
      # Requires KB to be started with org.killbill.payment.plugin.timeout=5s
      def test_authorize_plugin_timedout
        payment_key = 'payment2-' + rand(1000000).to_s
        payment_currency = 'USD'

        add_property('TEST_MODE', 'CONTROL')
        add_property('SLEEP_TIME_SEC', '6.0')

        auth1_key = payment_key + '-auth'
        auth1_amount = '123.5'
        got_exception = false

        begin
        auth = create_auth(@account.account_id, payment_key, auth1_key, auth1_amount, payment_currency, @user, @options)
        flunk("Call should have timedout")
        rescue KillBillClient::API::GatewayTimeout => e
          # 504 in case of timeout
        end
      end
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
