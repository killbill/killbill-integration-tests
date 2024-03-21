# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../..', __dir__)
$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'plugin_base'
require 'midi-smtp-server'
require 'mail'

module KillBillIntegrationTests
  class TestEmailNotification < KillBillIntegrationTests::PluginBase
    PLUGIN_KEY = 'email-notifications'
    PLUGIN_NAME = 'killbill-email-notifications'
    # Default to latest
    PLUGIN_VERSION = nil

    PLUGIN_PROPS = [{ key: 'pluginArtifactId', value: 'killbill-email-notifications-plugin' },
                    { key: 'pluginGroupId', value: 'org.kill-bill.billing.plugin.java' },
                    { key: 'pluginType', value: 'java' }].freeze

    SMTP_PORT = 2525
    # Be advised to adjust as necessary so that killbill emails can be received into the test email server
    # for local killbill this could be 127.0.0.1, for docker it must be the machine ip address where the test is running
    SMTP_HOST = '127.0.0.1'
    SMTP_FROM = 'xxx@yyy.com'

    PLUGIN_CONFIGURATION = 'org.killbill.billing.plugin.email-notifications.defaultEvents=INVOICE_NOTIFICATION,INVOICE_CREATION,INVOICE_PAYMENT_SUCCESS,INVOICE_PAYMENT_FAILED,SUBSCRIPTION_CANCEL' + "\n" \
                           "org.killbill.billing.plugin.email-notifications.smtp.host=#{SMTP_HOST}\n" \
                           "org.killbill.billing.plugin.email-notifications.smtp.port=#{SMTP_PORT}\n" \
                           'org.killbill.billing.plugin.email-notifications.smtp.useAuthentication=false' + "\n" \
                           'org.killbill.billing.plugin.email-notifications.smtp.userName=uuuuuu' + "\n" \
                           'org.killbill.billing.plugin.email-notifications.smtp.password=zzzzzz' + "\n" \
                           'org.killbill.billing.plugin.email-notifications.smtp.useSSL=false' + "\n" \
                           "org.killbill.billing.plugin.email-notifications.smtp.defaultSender=#{SMTP_FROM}"

    class SMTPServer < MidiSmtpServer::Smtpd
      def initialize(port, host, &handler)
        @handler = handler
        super(port, host)
      end

      def start
        super
      end

      def shutdown_and_wait_for_completion
        # gracefully connections down
        shutdown
        # check once if some connection(s) need(s) more time
        sleep 2 unless connections.zero?
        # stop all threads and connections
        stop
      end

      def on_message_data_event(ctx)
        @handler.call(ctx[:envelope][:from], "<#{SMTP_FROM}>")
        @handler.call(ctx[:envelope][:to][0], '<mathewgallager@kb.com>')

        # Just decode message ones to make sure, that this message ist readable
        mail = Mail.read_from_string(ctx[:message][:data])
        puts mail
      end
    end

    def setup
      @user = 'EmailNotification'
      setup_plugin_base(DEFAULT_KB_INIT_CLOCK, PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
      set_configuration(PLUGIN_NAME, PLUGIN_CONFIGURATION)

      resources = [{ key: 'killbill-email-notifications:UPCOMING_INVOICE_en_US', value: 'UpcomingInvoice.mustache' },
                   { key: 'killbill-email-notifications:SUCCESSFUL_PAYMENT_en_US', value: 'SuccessfulPayment.mustache' },
                   { key: 'killbill-email-notifications:FAILED_PAYMENT_en_US', value: 'FailedPayment.mustache' },
                   { key: 'killbill-email-notifications:SUBSCRIPTION_CANCELLATION_REQUESTED_en_US', value: 'SubscriptionCancellationRequested.mustache' },
                   { key: 'killbill-email-notifications:SUBSCRIPTION_CANCELLATION_EFFECTIVE_en_US', value: 'SubscriptionCancellationEffective.mustache' },
                   { key: 'killbill-email-notifications:PAYMENT_REFUND_en_US', value: 'PaymentRefund.mustache' },
                   { key: 'killbill-email-notifications:TEMPLATE_TRANSLATION_en_US', value: 'Translation_en_US.properties' }]

      resources.each do |entry|
        resource = get_resource_as_string("killbill-email-notifications/#{entry[:value]}")
        KillBillClient::Model::Tenant.upload_tenant_user_key_value(entry[:key], resource, @user, nil, nil, @options)
      end

      @smtp_server = SMTPServer.new(SMTP_PORT, '0.0.0.0') { |expected, actual| assert_equal(expected, actual) }
      @smtp_server.start

      # Create account
      data = {}
      data[:name] = 'Mathew Gallager'
      data[:external_key] = Time.now.to_i.to_s + '-' + rand(1_000_000).to_s
      data[:email] = 'mathewgallager@kb.com'
      data[:currency] = 'USD'
      data[:time_zone] = 'UTC'
      data[:address1] = '936 Wisconsin street'
      data[:address2] = nil
      data[:postal_code] = '94109'
      data[:company] = nil
      data[:city] = 'San Francisco'
      data[:state] = 'California'
      data[:country] = 'USA'
      data[:locale] = 'en_US'
      @account = create_account_with_data(@user, data, @options)

      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY, PLUGIN_VERSION)
      @smtp_server&.shutdown_and_wait_for_completion
    end

    def test_basic
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      # 8-24 : Invoice for Upcoming invoice
      kb_clock_add_days(24, nil, @options)

      # 8-31 Invoice for First invoice and payment
      kb_clock_add_days(7, nil, @options)

      # Invoice for refund
      payment_id = @account.payments(@options).first.payment_id
      refund(payment_id, '5.0', nil, @user, @options)

      # 9-15 Invoice for Cancellation Requested Date
      kb_clock_add_days(15, nil, @options)
      requested_date = '2013-09-15'
      entitlement_policy = nil
      billing_policy = 'END_OF_TERM'
      use_requested_date_for_billing = false

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      # 9-30 Invoice for Cancellation Effective Date
      kb_clock_add_days(15, nil, @options)
    end
  end
end
