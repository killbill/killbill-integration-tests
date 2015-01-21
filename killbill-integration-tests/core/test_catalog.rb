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

    def test_add_plan
      create_basic_entitlement(1, 'MONTHLY', '2013-08-01', '2013-09-01', 1000.0)

      add_days_and_check_invoice_item(31, 2, 'basic-monthly', '2013-09-01', '2013-10-01', 1000.0)

      # Effective date of the second catalog is 2013-10-01
      upload_catalog('Catalog-v3.xml')

      # Original subscription is grandfathered
      add_days_and_check_invoice_item(30, 3, 'basic-monthly', '2013-10-01', '2013-11-01', 1000.0)

      # The annual plan is only present in the v3 catalog
      create_basic_entitlement(4, 'ANNUAL', '2013-10-01', '2014-10-01', 14000.0)

      add_days_and_check_invoice_item(31, 5, 'basic-monthly', '2013-11-01', '2013-12-01', 1000.0)
    end

    def test_create_alignment
      upload_catalog('Catalog-CreateAlignment.xml')

      bp = create_basic_entitlement(1, 'MONTHLY', '2013-08-01', nil, 0.0)

      # Move the clock to 2013-08-15
      add_days(14)

      # Add a first add-on with a START_OF_BUNDLE creation alignment. Note that the subscription start date is aligned
      # with the bundle creation date (2013-08-01)
      create_ao_entitlement(bp, 2, 'BasicAOStartOfBundle', 'MONTHLY', '2013-08-01', 0, '2013-08-15')

      # Add a second add-on with a START_OF_SUBSCRIPTION creation alignment. Note that the subscription start date is aligned
      # with the add-on subscription creation date (2013-08-15)
      create_ao_entitlement(bp, 3, 'BasicAOStartOfSubscription', 'MONTHLY', '2013-08-15', 0, '2013-08-15')

      # Move the clock to 2013-08-31 (30 days trial)
      add_days(16)

      # The first evergreen invoice will contain the line items for the base plan and the bundle-aligned add-on
      invoice = check_invoice_balance(4, '2013-08-31', 1100.0)
      check_invoice_item(invoice.items[0], invoice.invoice_id, 100.0, 'USD', 'RECURRING', 'BasicAOStartOfBundle-monthly', 'BasicAOStartOfBundle-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(invoice.items[1], invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Move the clock to 2013-09-14: the invoice will just contain the line item for the subscription-aligned add-on
      # Note that we configured a billing alignment of SUBSCRIPTION for the product BasicAOStartOfSubscription, to avoid dealing with pro-rations
      # For an ACCOUNT billing alignment, the line item would be from 2013-09-14 to 2013-09-30 ($77.42)
      add_days_and_check_invoice_item(14, 5, 'BasicAOStartOfSubscription-monthly', '2013-09-14', '2013-10-14', 150)

      # Move the clock to 2013-09-30
      add_days(16)

      invoice = check_invoice_balance(6, '2013-09-30', 1100.0)
      check_invoice_item(invoice.items[0], invoice.invoice_id, 100.0, 'USD', 'RECURRING', 'BasicAOStartOfBundle-monthly', 'BasicAOStartOfBundle-monthly-evergreen', '2013-09-30', '2013-10-31')
      check_invoice_item(invoice.items[1], invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-09-30', '2013-10-31')

      # Move the clock to 2013-10-14
      add_days_and_check_invoice_item(14, 7, 'BasicAOStartOfSubscription-monthly', '2013-10-14', '2013-11-14', 150)
    end

    private

    def create_basic_entitlement(invoice_nb=1, billing_period='MONTHLY', start_date='2013-08-01', end_date='2013-09-01', amount=1000.0)
      bp = create_entitlement_base(@account.account_id, 'Basic', billing_period, 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Basic', 'BASE', billing_period, 'DEFAULT', start_date, nil)
      if end_date.nil?
        check_fixed_item(invoice_nb, 'basic-' + billing_period.downcase, start_date, amount)
      else
        check_evergreen_item(invoice_nb, 'basic-' + billing_period.downcase, start_date, end_date, amount)
      end
      bp
    end

    def create_ao_entitlement(bp, invoice_nb, plan, billing_period='MONTHLY', start_date='2013-08-01', amount=1000.0, invoice_date=start_date)
      ao = create_entitlement_ao(bp.bundle_id, plan, billing_period, 'DEFAULT', @user, @options)
      check_subscription(ao, plan, 'ADD_ON', billing_period, 'DEFAULT', start_date, nil, start_date, nil)
      check_fixed_item(invoice_nb, plan + '-' + billing_period.downcase, invoice_date, amount, start_date)
      ao
    end

    def add_days(days)
      kb_clock_add_days(days, nil, @options)
    end

    def add_days_and_check_invoice_balance(days, invoice_nb, invoice_date, amount)
      kb_clock_add_days(days, nil, @options)
      check_invoice_balance(invoice_nb, invoice_date, amount)
    end

    def add_days_and_check_invoice_item(days, invoice_nb, plan, start_date, end_date, amount, invoice_date=start_date)
      kb_clock_add_days(days, nil, @options)
      check_evergreen_item(invoice_nb, plan, invoice_date, end_date, amount, start_date)
    end

    def check_fixed_item(invoice_nb, plan, invoice_date, amount, start_date=invoice_date)
      new_invoice = check_invoice_balance(invoice_nb, invoice_date, amount)
      check_invoice_item(new_invoice.items[0], new_invoice.invoice_id, amount, 'USD', 'FIXED', plan, plan + '-trial', start_date, nil)
    end

    def check_evergreen_item(invoice_nb, plan, invoice_date, end_date, amount, start_date=invoice_date)
      new_invoice = check_invoice_balance(invoice_nb, invoice_date, amount)
      check_invoice_item(new_invoice.items[0], new_invoice.invoice_id, amount, 'USD', 'RECURRING', plan, plan + '-evergreen', start_date, end_date)
    end

    def check_invoice_balance(invoice_nb, invoice_date, amount)
      wait_for_expected_clause(invoice_nb, @account, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(invoice_nb, all_invoices.size)

      sort_invoices!(all_invoices)
      all_invoices.each do |invoice|
        invoice.items.sort! do |a, b|
          a.amount <=> b.amount
        end
      end

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
