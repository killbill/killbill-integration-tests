$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestCatalog < Base

    def setup
      @user = 'Catalog'
      setup_base(@user)

      upload_catalog('Catalog-v1.xml')

      @account = create_account(@user, nil, @options)
    end

    def teardown
      teardown_base
    end

    def test_price_increase
      create_basic_entitlement(1, 'MONTHLY', '2013-08-01', '2013-09-01', 1000.0)

      # Effective date of the second catalog is 2013-09-01
      upload_catalog('Catalog-v2.xml')

      # Original subscription is grandfathered
      add_days_and_check_invoice_item(31, 2, 'basic-monthly', '2013-09-01', '2013-10-01', 1000.0)

      # Create a new subscription and check the new price is effective
      create_basic_entitlement(3, 'MONTHLY', '2013-09-01', '2013-10-01', 1200.0)

      add_days_and_check_invoice_balance(30, 4, '2013-10-01', 2200.0)
    end

    private

    def create_basic_entitlement(invoice_nb=1, billing_period='MONTHLY', start_date='2013-08-01', end_date='2013-09-01', amount=1000.0)
      bp = create_entitlement_base(@account.account_id, 'Basic', billing_period, 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Basic', 'BASE', billing_period, 'DEFAULT', start_date, nil)
      check_evergreen_item(invoice_nb, 'basic-' + billing_period.downcase, start_date, end_date, amount)
      bp
    end

    def add_days_and_check_invoice_balance(days, invoice_nb, invoice_date, amount)
      kb_clock_add_days(days, nil, @options)
      check_invoice_balance(invoice_nb, invoice_date, amount)
    end

    def add_days_and_check_invoice_item(days, invoice_nb, plan, start_date, end_date, amount)
      kb_clock_add_days(days, nil, @options)
      check_evergreen_item(invoice_nb, plan, start_date, end_date, amount)
    end

    def check_evergreen_item(invoice_nb, plan, start_date, end_date, amount)
      new_invoice = check_invoice_balance(invoice_nb, start_date, amount)
      check_invoice_item(new_invoice.items[0], new_invoice.invoice_id, amount, 'USD', 'RECURRING', plan, plan + '-evergreen', start_date, end_date)
    end

    def check_invoice_balance(invoice_nb, invoice_date, amount)
      wait_for_expected_clause(invoice_nb, @account, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(invoice_nb, all_invoices.size)

      new_invoice = all_invoices[invoice_nb - 1]
      check_invoice_no_balance(new_invoice, amount, 'USD', invoice_date)

      new_invoice
    end

    def upload_catalog(name)
      catalog_file_xml = get_resource_as_string(name)
      KillBillClient::Model::Catalog.upload_tenant_catalog(catalog_file_xml, @user, 'New Catalog Version', 'Upload catalog for tenant', @options)
    end
  end
end
