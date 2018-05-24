$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestCloudWithDetails < Base

    def setup
      setup_base

      upload_catalog("usage/Cloud.xml", false, @user, @options)

      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    def test_detail_with_0_price_first_tier

      # Set per-tenant config detailed mode
      detail_mode

      #
      # Step 1. Create a subscription associated with the account `@account`
      #
      bp = create_entitlement_base(@account.account_id, 'LB', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)



      # All units will be prices at the price of the first tier (because we did not reach the limit of first tier)
      usage_input = [{:unit_type => 'lb-hourly',
                      :usage_records => [{:record_date => '2013-08-10', :amount => 101}]
                     }]

      record_usage(bp.subscription_id, usage_input, @user, @options)

      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 1.0, 'USD', '2013-09-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 0.00, 'USD', 'RECURRING', 'lb-monthly', 'lb-monthly-evergreen', '2013-09-01', '2013-10-01')
      if aggregate_mode?
        check_usage_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 1.00, 'USD', 'USAGE', 'lb-monthly', 'lb-monthly-evergreen', 'lb-monthly-hourly-usage-type', '2013-08-01', '2013-09-01')
        check_invoice_consumable_item_detail(second_invoice.items[1],
                                             [{:tier => 1, :unit_type => 'lb-hourly', :unit_qty => 100, :tier_price => 0.00 },
                                              {:tier => 2, :unit_type => 'lb-hourly', :unit_qty => 1, :tier_price => 1.00 }], 1.00)
      else
        check_usage_invoice_item_w_quantity(second_invoice.items[1], second_invoice.invoice_id, 0.00, 'USD', 'USAGE', 'lb-monthly', 'lb-monthly-evergreen', 'lb-monthly-hourly-usage-type', '2013-08-01', '2013-09-01', 0.00, 100)
        check_usage_invoice_item_w_quantity(second_invoice.items[2], second_invoice.invoice_id, 1.00, 'USD', 'USAGE', 'lb-monthly', 'lb-monthly-evergreen', 'lb-monthly-hourly-usage-type', '2013-08-01', '2013-09-01', 1.00, 1)
      end

      # All units will be prices at the price of the second tier (because we reached the limit of the first tier but did not reach the limit of second tier)
      usage_input = [{:unit_type => 'lb-hourly',
                      :usage_records => [{:record_date => '2013-09-01', :amount => 1000}]
                     }]


      record_usage(bp.subscription_id, usage_input, @user, @options)

      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 900.0, 'USD', '2013-10-01')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 0.0, 'USD', 'RECURRING', 'lb-monthly', 'lb-monthly-evergreen', '2013-10-01', '2013-11-01')

      if aggregate_mode?
        check_usage_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 900.0, 'USD', 'USAGE', 'lb-monthly', 'lb-monthly-evergreen', 'lb-monthly-hourly-usage-type', '2013-09-01', '2013-10-01')

        check_invoice_consumable_item_detail(third_invoice.items[1],
                                             [{:tier => 1, :unit_type => 'lb-hourly', :unit_qty => 100, :tier_price => 0.00 },
                                              {:tier => 2, :unit_type => 'lb-hourly', :unit_qty => 900, :tier_price => 1.00 }], 900.00)
      else
        check_usage_invoice_item_w_quantity(third_invoice.items[1], third_invoice.invoice_id, 0.00, 'USD', 'USAGE', 'lb-monthly', 'lb-monthly-evergreen', 'lb-monthly-hourly-usage-type', '2013-09-01', '2013-10-01', 0.00, 100)
        check_usage_invoice_item_w_quantity(third_invoice.items[2], third_invoice.invoice_id, 900.00, 'USD', 'USAGE', 'lb-monthly', 'lb-monthly-evergreen', 'lb-monthly-hourly-usage-type', '2013-09-01', '2013-10-01', 1.00, 900)
      end
    end

  end
end
