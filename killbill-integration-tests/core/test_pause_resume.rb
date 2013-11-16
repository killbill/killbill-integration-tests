$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestPauseResume < Base

    def setup
      @user = "TestPauseResume"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)

    end

    def teardown
      teardown_base
    end

    def test_basic

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)


      # Second invoice
      # Move clock  (BP out of trial)
      kb_clock_add_days(30, nil, @options) # 31/08/2013

      all_invoices = @account.invoices(true, @options)
      assert_equal(all_invoices.size, 2)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice(second_invoice, 500.00, 'USD', "2013-08-31", 0)
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Move clock  and pause bundle
      kb_clock_add_days(5, nil, @options) # 5/09/2013
      pause_bundle(bp.bundle_id, nil, @user, @options)

      # Verify last invoice was adjusted
      sleep 3; # There is no sync on pause_bundle to wait for invoice generation
      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice(second_invoice, 83.35, 'USD', "2013-08-31", 0)
      assert_equal(3, second_invoice.items.size)
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -416.65, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      check_invoice_item(second_invoice.items[2], second_invoice.invoice_id, 416.65, 'USD', 'CBA_ADJ', nil, nil, '2013-09-05', '2013-09-05')

      # Move clock
      kb_clock_add_days(5, nil, @options) # 10/09/2013
      resume_bundle(bp.bundle_id, nil, @user, @options)

      # Verify last invoice was adjusted
      sleep 3; # There is no sync on resume_bundle to wait for invoice generation
      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice(third_invoice, 322.60, 'USD', "2013-09-10", 0)
      assert_equal(2, third_invoice.items.size)
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 322.60, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-10', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, -322.60, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')


      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(subscriptions.size, 1)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-01", nil, "2013-08-01", nil)
      check_events(bp.events, [{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                               {:type => "START_BILLING", :date => "2013-08-01"},
                               {:type => "PHASE", :date => "2013-08-31"},
                               {:type => "PAUSE_ENTITLEMENT", :date => "2013-09-05"},
                               {:type => "PAUSE_BILLING", :date => "2013-09-05"},
                               {:type => "RESUME_ENTITLEMENT", :date => "2013-09-10"},
                               {:type => "RESUME_BILLING", :date => "2013-09-10"}])

    end

  end
end

