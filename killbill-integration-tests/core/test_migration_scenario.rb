$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestMigrationScenario < Base

    def setup
      setup_base

      catalog_file_xml = get_resource_as_string("Catalog-Simple.xml")
      KillBillClient::Model::Catalog.upload_tenant_catalog(catalog_file_xml, @user, 'New Catalog Version', 'Upload catalog for tenant', @options)

      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)

    end

    def teardown
      teardown_base
    end


    def test_migration_scenario

      # Start one year earlier than any other test (because we end up moving the clock by 11 months so we don't want all kinds of parasite account to start kicking it and impacting the timing of our test)
      kb_clock_set('2012-08-01T06:00:00.000Z', nil, @options)

      # Disable invoice processing for account
      @account.set_auto_invoicing_off(@user, 'test_migration_scenario', 'Disable invoice prior block/unblock', @options)

      # 01/08/2012: First subscription (MONTHLY -> billing alignment is ACCOUNT) -> BCD will be 1st because there is no trial
      bp1 = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp1, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', '2012-08-01', nil)

      # We are using a nil effective_date to make sure that BlockingState event is created with clock.getUTCNow() and correct ordering between 'ENT_STARTED' and 'INIT_MIGRATION' occurs
      # and therefore junction correctly realize that we are in blockedBilling mode.
      set_blocking_state(bp1.bundle_id, 'INIT_MIGRATION', 'MigrationService', true, true, true, nil, @user, @options)
      set_blocking_state(bp1.bundle_id, 'CUTOFF_MIGRATION', 'MigrationService', false, false, false, '2013-07-01', @user, @options)

      # 10/08/2012
      kb_clock_add_days(9, nil, @options)

      # Second subscription (ANNUAL -> billing alignment is SUBSCRIPTION)
      bp2 = create_entitlement_base(@account.account_id, 'Basic', 'ANNUAL', 'DEFAULT', @user, @options)
      check_entitlement(bp2, 'Basic', 'BASE', 'ANNUAL', 'DEFAULT', '2012-08-10', nil)


      # Same remark here regarding the nil effective_date
      set_blocking_state(bp2.bundle_id, 'INIT_MIGRATION', 'MigrationService', true, true, true, nil, @user, @options)
      set_blocking_state(bp2.bundle_id, 'CUTOFF_MIGRATION', 'MigrationService', false, false, false, '2013-08-10', @user, @options)

      # Add 11 months
      kb_clock_set('2013-07-01T06:00:05.000Z', nil, @options)

      @account.remove_auto_invoicing_off(@user, 'test_migration_scenario', 'Disable invoice prior block/unblock', @options)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      first_invoice = all_invoices[0]
      check_invoice_no_balance(first_invoice, 1000.00, 'USD', '2013-07-01')
      check_invoice_item(first_invoice.items[0], first_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-07-01', '2013-08-01')


      # '2013-08-01'
      kb_clock_add_months(1, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 1000.00, 'USD', '2013-08-01')
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-01', '2013-09-01')

      # '2013-08-10'
      kb_clock_add_days(9, nil, @options)
      wait_for_expected_clause(3, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 10000.00, 'USD', '2013-08-10')
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 10000.00, 'USD', 'RECURRING', 'basic-annual', 'basic-annual-evergreen', '2013-08-10', '2014-08-10')

      # '2013-09-01'
      kb_clock_add_days(22, nil, @options)
      wait_for_expected_clause(4, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      fourth_invoice = all_invoices[3]
      check_invoice_no_balance(fourth_invoice, 1000.00, 'USD', '2013-09-01')
      check_invoice_item(fourth_invoice.items[0], fourth_invoice.invoice_id, 1000.00, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-09-01', '2013-10-01')

    end


  end
end

