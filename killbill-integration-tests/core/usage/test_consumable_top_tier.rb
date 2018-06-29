$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestConsumableTopTierPolicy < Base

    def setup
      setup_base

      upload_catalog("usage/ConsumableTopTierPolicy.xml", false, @user, @options)

      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    def test_demo_with_multiple_units

      #
      # Step 1. Create a subscription associated with the account `@account` 
      #
      bp = create_entitlement_base(@account.account_id, 'Something', 'MONTHLY', 'DEFAULT', @user, @options)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)


      # All units will be prices at the price of the first tier (because we did not reach the limit of first tier)
      usage_input = [{:unit_type => 'XYZ',
                      :usage_records => [{:record_date => '2013-08-01', :amount => 10},
                                         {:record_date => '2013-08-31', :amount => 5}]
                     }]

      record_usage(bp.subscription_id, usage_input, @user, @options)

      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 200.0, 'USD', '2013-09-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 0.0, 'USD', 'RECURRING', 'something-monthly', 'something-monthly-evergreen', '2013-09-01', '2013-10-01')

      if aggregate_mode?
        check_usage_invoice_item(second_invoice.items[1], second_invoice.invoice_id, 200.0, 'USD', 'USAGE', 'something-monthly', 'something-monthly-evergreen', 'xyz-usage', '2013-08-01', '2013-09-01')
        check_invoice_consumable_item_detail(second_invoice.items[1],
                                             [{:tier => 1, :unit_type => 'XYZ', :unit_qty => 2, :tier_price => 100.00 }], 200.00)
      else
        check_usage_invoice_item_w_quantity(second_invoice.items[1], second_invoice.invoice_id, 200.0, 'USD', 'USAGE', 'something-monthly', 'something-monthly-evergreen', 'xyz-usage', '2013-08-01', '2013-09-01', 100.00, 2)
      end


      # All units will be prices at the price of the second tier (because we reached the limit of the first tier but did not reach the limit of second tier)
      usage_input = [{:unit_type => 'XYZ',
                      :usage_records => [{:record_date => '2013-09-01', :amount => 1000},
                                         {:record_date => '2013-09-30', :amount => 100}]
                     }]


      record_usage(bp.subscription_id, usage_input, @user, @options)

      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 1100.0, 'USD', '2013-10-01')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 0.0, 'USD', 'RECURRING', 'something-monthly', 'something-monthly-evergreen', '2013-10-01', '2013-11-01')

      if aggregate_mode?
        check_usage_invoice_item(third_invoice.items[1], third_invoice.invoice_id, 1100.0, 'USD', 'USAGE', 'something-monthly', 'something-monthly-evergreen', 'xyz-usage', '2013-09-01', '2013-10-01')
        check_invoice_consumable_item_detail(third_invoice.items[1],
                                             [{:tier => 2, :unit_type => 'XYZ',  :unit_qty => 110, :tier_price => 10.00 }], 1100.00)
      else
        check_usage_invoice_item_w_quantity(third_invoice.items[1], third_invoice.invoice_id, 1100.0, 'USD', 'USAGE', 'something-monthly', 'something-monthly-evergreen', 'xyz-usage', '2013-09-01', '2013-10-01', 10.00, 110)
      end

    end


  end
end
