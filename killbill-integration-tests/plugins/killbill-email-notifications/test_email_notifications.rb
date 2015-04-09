$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)

require 'test_base'
require 'mini-smtp-server'

module KillBillIntegrationTests

  #
  # Will require Kill Bill to be started with org.killbill.invoice.dryRunNotificationSchedule=7d
  #
  class TestEmailNotification < Base


    class SMTPServer < MiniSmtpServer

      def initialize(port, ip, &handler)
        super(port, ip, 4, $stderr, false, true)
        @handler = handler
      end


      def shutdown_and_wait_for_completion
        shutdown
        while(connections > 0)
          sleep 0.01
        end
        stop
        join
      end

      def new_message_event(message_hash)
        puts "# New email received:"
        puts "-- From: #{message_hash[:from]}"
        puts "-- To:   #{message_hash[:to]}"
        puts "--"
        puts "-- " + message_hash[:data].gsub(/\r\n/, "\r\n-- ")
        puts
        #@handler.call(message_hash)
      end

    end

    def setup
      @user = "EmailNotification"
      setup_base(@user)

      resources = [{:key => 'killbill-email-notifications:UPCOMING_INVOICE_en_US', :value => 'UpcomingInvoice.mustache' },
                   {:key => 'killbill-email-notifications:SUCCESSFUL_PAYMENT_en_US', :value => 'SuccessfulPayment.mustache' },
                   {:key => 'killbill-email-notifications:FAILED_PAYMENT_en_US', :value => 'FailedPayment.mustache' },
                   {:key => 'killbill-email-notifications:SUBSCRIPTION_CANCELLATION_REQUESTED_en_US', :value => 'SubscriptionCancellationRequested.mustache' },
                   {:key => 'killbill-email-notifications:SUBSCRIPTION_CANCELLATION_EFFECTIVE_en_US', :value => 'SubscriptionCancellationEffective.mustache' },
                   {:key => 'killbill-email-notifications:PAYMENT_REFUND_en_US', :value => 'PaymentRefund.mustache' },
                   {:key => 'killbill-email-notifications:TEMPLATE_TRANSLATION_en_US', :value => 'Translation_en_US.properties' },
      ]

      resources.each do |entry|
        resource = get_resource_as_string("killbill-email-notifications/#{entry[:value]}")
        KillBillClient::Model::Tenant.upload_tenant_user_key_value(entry[:key], resource, @user, nil, nil, @options)
      end

      @smtp_server = SMTPServer.new(2525, "127.0.0.1")
      #@smtp_server.start

      # Create account
      default_time_zone = nil


      data = {}
      data[:name] = 'Mathew Gallager'
      data[:external_key] = Time.now.to_i.to_s + "-" + rand(1000000).to_s
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
      teardown_base
      #@smtp_server.shutdown_and_wait_for_completion
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
      refund(payment_id, '5.0',nil, @user, @options)


      # 9-15 Invoice for Cancellation Requested Date
      kb_clock_add_days(15, nil, @options)
      requested_date = "2013-09-15"
      entitlement_policy = nil
      billing_policy = "END_OF_TERM"
      use_requested_date_for_billing = false

      bp.cancel(@user, nil, nil, requested_date, entitlement_policy, billing_policy, use_requested_date_for_billing, @options)

      # 9-30 Invoice for Cancellation Effective Date
      kb_clock_add_days(15, nil, @options)

    end

  end
end
