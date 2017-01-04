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

    def test_update_bcd_immediate

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
      effective_from_date  = nil
      bp.update_bcd(@user, nil, nil, effective_from_date, @options)

      # Add 6 days to reach new effective date for BCD
      kb_clock_add_days(6, nil, @options) # "2013-08-31"
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
