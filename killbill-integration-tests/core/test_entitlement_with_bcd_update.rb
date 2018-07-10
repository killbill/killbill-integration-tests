# encoding: utf-8

$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestEntitlementBCDUpdateTest < Base

    def setup
      setup_base
      #
      # Catalog only contains BASE 'Sports' and AO 'OilSlick', 'RemoteControl' where those have 3 phase (TRIAL, DISCOUNT, EVERGREEN)
      #
      upload_catalog('Catalog-Simple.xml', false, @user, @options)
      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end


    def test_with_bcd_change_in_the_future_v1

      # Create initial subscription MONTHLY from 2013-08-01 -> 2013-09-01, ...
      bp = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      assert_equal('EVERGREEN', bp.phase_type)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(1, all_invoices.size)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 1000.00, 'USD', '2013-08-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-01', '2013-09-01')

      # Change BCD for subscription to 16. Make the change effective on the 16 -- not immediately otherwsie invoicing would immediately recompute invoices to realign things on the 16.
      bp.bill_cycle_day_local = 16;
      effective_from_date  = '2013-08-16'
      bp.update_bcd(@user, nil, nil, effective_from_date, nil, @options)


      # Change plan to also make it effective on the 16
      bp = bp.change_plan({:productName => 'Basic', :billingPeriod => 'ANNUAL', :priceList => 'DEFAULT'}, @user, nil, nil, effective_from_date, nil, nil, false, @options)


      # Position the clock to be on 2013-08-16 and trigger the changes
      kb_clock_add_days(15, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)


      # Verify we see 1 new invoice and the ANNUAL is not realigned on this new BCD. There is a pro-ration credit for the part of the MONTHLY that was not used.
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 9483.87, 'USD', '2013-08-16')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 10000.00, 'USD', 'RECURRING', 'basic-annual', 'basic-annual-evergreen', '2013-08-16', '2014-08-16')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -516.13, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-16', '2013-09-01')


    end


    def test_with_bcd_change_immediate

      bp = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      assert_equal('EVERGREEN', bp.phase_type)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(1, all_invoices.size)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 1000.00, 'USD', '2013-08-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-01', '2013-09-01')

      kb_clock_add_days(6, nil, @options) # "2013-08-07"

      # Update BCD to be the 7
      bp.bill_cycle_day_local = 7;
      effective_from_date  = nil
      bp.update_bcd(@user, nil, nil, effective_from_date, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 193.55, 'USD', '2013-08-07')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-07', '2013-09-07')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -806.45, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-07', '2013-09-01')
    end



    def test_with_bcd_change_in_the_future_v2

      bp = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      assert_equal('EVERGREEN', bp.phase_type)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(1, all_invoices.size)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 1000.00, 'USD', '2013-08-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-01', '2013-09-01')

      # Update BCD to be the 7
      bp.bill_cycle_day_local = 7;
      effective_from_date  = '2013-08-07'
      bp.update_bcd(@user, nil, nil, effective_from_date, nil, @options)

      # Add 6 days to reach new effective date for BCD
      kb_clock_add_days(6, nil, @options) # '2013-08-07'
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 193.55, 'USD', '2013-08-07')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-07', '2013-09-07')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -806.45, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-07', '2013-09-01')
    end

    def test_with_bcd_change_in_the_past

      bp = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      assert_equal('EVERGREEN', bp.phase_type)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(1, all_invoices.size)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 1000.00, 'USD', '2013-08-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-01', '2013-09-01')

      kb_clock_add_days(15, nil, @options) # "2013-08-15"

      # Update BCD to be the 7
      bp.bill_cycle_day_local = 7;
      effective_from_date  = '2013-08-06'

      # First check without force_past_effective_date flag
      begin
        bp.update_bcd(@user, nil, nil, effective_from_date, nil, @options)
        assert.fail "Unexpected success BCD operation for a effective date in the past"
      rescue KillBillClient::API::BadRequest
      end

      # Re-issue the call with force_past_effective_date = true
      bp.update_bcd(@user, nil, nil, effective_from_date, true, @options)

      # Check past invoice has been repaired and subscription reinvoiced with correct date
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 193.55, 'USD', '2013-08-16')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-07', '2013-09-07')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -806.45, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-07', '2013-09-01')
    end

    def test_with_multiple_change_same_day

      bp = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      assert_equal('EVERGREEN', bp.phase_type)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(1, all_invoices.size)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 1000.00, 'USD', '2013-08-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-01', '2013-09-01')

      # Update first BCD to be the 9
      bp.bill_cycle_day_local = 7;
      effective_from_date  = '2013-08-07'
      bp.update_bcd(@user, nil, nil, effective_from_date, nil, @options)

      # Then, update first BCD to be the 8
      bp.bill_cycle_day_local = 7;
      effective_from_date  = '2013-08-07'
      bp.update_bcd(@user, nil, nil, effective_from_date, nil, @options)


      # Finally, update first BCD to be the 7
      bp.bill_cycle_day_local = 7;
      effective_from_date  = '2013-08-07'
      bp.update_bcd(@user, nil, nil, effective_from_date, nil, @options)

      # Add 6 days to reach new effective date for BCD
      kb_clock_add_days(6, nil, @options) # '2013-08-07'
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 193.55, 'USD', '2013-08-07')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-07', '2013-09-07')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -806.45, 'USD', 'REPAIR_ADJ', nil, nil, '2013-08-07', '2013-09-01')

    end

  end
end
