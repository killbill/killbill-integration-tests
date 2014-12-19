$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestCatalog < Base

    def setup
      @user = "Catalog"
      setup_base(@user)

      catalog_file_xml = get_resource_as_string("Catalog-v1.xml")
      KillBillClient::Model::Catalog.upload_tenant_catalog(catalog_file_xml, @user, "Initial Catalog", "upload catalog for tenant", @options)

      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
    end

    def teardown
      teardown_base
    end

    def test_price_increase

      bp1 = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp1, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)


      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(1, all_invoices.size)
      new_invoice = all_invoices[0]
      check_invoice_no_balance(new_invoice, 1000.0, 'USD', '2013-08-01')
      check_invoice_item(new_invoice.items[0], new_invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-01', '2013-09-01')


      catalog_file_xml2 = get_resource_as_string("Catalog-v2.xml")
      KillBillClient::Model::Catalog.upload_tenant_catalog(catalog_file_xml2, @user, "New Catalog Version (Change of price)", "upload catalog for tenant", @options)

      kb_clock_add_days(31, nil, @options)
      wait_for_expected_clause(2, @account, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      new_invoice = all_invoices[1]
      check_invoice_no_balance(new_invoice, 1000.0, 'USD', '2013-09-01')
      check_invoice_item(new_invoice.items[0], new_invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-09-01', '2013-10-01')


      bp2 = create_entitlement_base(@account.account_id, 'Basic', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp2, 'Basic', 'BASE', 'MONTHLY', 'DEFAULT', '2013-09-01', nil)

      wait_for_expected_clause(3, @account, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(3, all_invoices.size)
      new_invoice = all_invoices[2]
      check_invoice_no_balance(new_invoice, 1200.0, 'USD', '2013-09-01')
      check_invoice_item(new_invoice.items[0], new_invoice.invoice_id, 1200.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-09-01', '2013-10-01')

      kb_clock_add_days(30, nil, @options)
      wait_for_expected_clause(4, @account, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(4, all_invoices.size)
      new_invoice = all_invoices[3]
      check_invoice_no_balance(new_invoice, 2200.0, 'USD', '2013-10-01')
    end

  end
end
