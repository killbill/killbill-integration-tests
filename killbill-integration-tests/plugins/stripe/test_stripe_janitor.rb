# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('.', __dir__)

require 'stripe_base'

require 'toxiproxy'

module KillBillIntegrationTests
  class TestStripeJanitor < KillBillIntegrationTests::StripeBase
    PROXY_NAME = 'integration_tests'
    PROXY_HOST = 'localhost'
    PROXY_PORT = 22_222

    class << self
      def startup
        # Setup Toxiproxy
        Toxiproxy.populate([
                             {
                               name: PROXY_NAME,
                               listen: "#{PROXY_HOST}:#{PROXY_PORT}",
                               upstream: 'api.stripe.com:443'
                             }
                           ])
      end

      def shutdown
        Toxiproxy[PROXY_NAME.to_sym].destroy
      end
    end

    PLUGIN_CONFIGURATION_WITH_PROXY = "org.killbill.billing.plugin.stripe.apiKey=#{ENV['STRIPE_API_KEY']}" + "\n" \
                                      "org.killbill.billing.plugin.stripe.publicKey=#{ENV['STRIPE_PUBLIC_KEY']}" + "\n" \
                                      'org.killbill.billing.plugin.stripe.readTimeout=5000' + "\n" \
                                      "org.killbill.billing.plugin.stripe.apiBase=https://#{PROXY_HOST}:#{PROXY_PORT}"

    def setup
      super
      return if Gem::Version.new(@plugins_info.version).segments[0] < 8

      set_configuration(PLUGIN_NAME, PLUGIN_CONFIGURATION_WITH_PROXY)

      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, 'killbill-stripe', true, { 'token' => 'tok_visa' }, @user, @options)
    end

    def test_proxy_down
      omit_if(Gem::Version.new(@plugins_info.version).segments[0] < 8, 'Janitor support requires Stripe plugin 8 or later')
      error_message = "IOException during API request to Stripe (https://localhost:22222): Connection refused (Connection refused) Please check your internet connection and try again. If this problem persists,you should check Stripe's service status at https://twitter.com/stripestatus, or let us know at support@stripe.com."

      transaction = nil
      toxiproxy.down do
        transaction = trigger_purchase('PLUGIN_FAILURE', error_message)
      end

      transaction = get_transaction_by_key(transaction.payment_external_key, transaction.transaction_external_key, @options)
      check_transaction(transaction, 'PLUGIN_FAILURE', error_message)
    end

    def test_timeout
      omit_if(Gem::Version.new(@plugins_info.version).segments[0] < 8, 'Janitor support requires Stripe plugin 8 or later')
      error_message = "IOException during API request to Stripe (https://localhost:22222): Remote host terminated the handshake Please check your internet connection and try again. If this problem persists,you should check Stripe's service status at https://twitter.com/stripestatus, or let us know at support@stripe.com."

      transaction = nil
      # The transaction will NOT happen
      toxiproxy.downstream(:timeout, timeout: 1000).apply do
        # The Janitor GET refresh call will fail too (timeout still being applied), hence the UNKNOWN
        transaction = trigger_purchase('UNKNOWN', error_message)
      end

      # Check the recovery behavior for the Janitor
      transaction = get_transaction_by_key(transaction.payment_external_key, transaction.transaction_external_key, @options)
      check_transaction(transaction, 'PLUGIN_FAILURE', "Payment didn't happen - Cancelled by Janitor")
    end

    private

    def trigger_purchase(status = 'PAYMENT_FAILURE', gateway_error = nil, gateway_error_code = nil)
      payment_key = Time.now.to_i.to_s
      transaction = create_purchase(@account.account_id, payment_key, payment_key, 16, @account.currency, @user, @options)
      check_transaction(transaction, status, gateway_error, gateway_error_code)
      transaction
    end

    def check_transaction(transaction, status = 'PAYMENT_FAILURE', gateway_error = nil, gateway_error_code = nil)
      assert_equal(status, transaction.status)
      assert_equal(gateway_error, transaction.gateway_error_msg)
      assert_equal(gateway_error_code, transaction.gateway_error_code)
    end

    def toxiproxy
      Toxiproxy[PROXY_NAME.to_sym]
    end
  end
end
