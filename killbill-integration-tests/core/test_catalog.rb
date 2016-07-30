$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestCatalog < Base

    def setup
      setup_base
      upload_catalog('Catalog-v1.xml', false, @user, @options)
      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    # Increase the price in a subsequent catalog
    def test_price_increase
      create_basic_entitlement(1, 'MONTHLY', '2013-08-01', '2013-09-01', 1000.0)

      # Effective date of the second catalog is 2013-09-01
      upload_catalog('Catalog-v2.xml', false, @user, @options)

      # Original subscription is grandfathered
      add_days_and_check_invoice_item(31, 2, 'basic-monthly', '2013-09-01', '2013-10-01', 1000.0)

      # Create a new subscription and check the new price is effective
      create_basic_entitlement(3, 'MONTHLY', '2013-09-01', '2013-10-01', 1200.0)

      add_days_and_check_invoice_balance(30, 4, '2013-10-01', 2200.0)
    end

    # Add a plan in a subsequent catalog
    def test_add_plan
      create_basic_entitlement(1, 'MONTHLY', '2013-08-01', '2013-09-01', 1000.0)

      add_days_and_check_invoice_item(31, 2, 'basic-monthly', '2013-09-01', '2013-10-01', 1000.0)

      # Effective date of the second catalog is 2013-10-01
      upload_catalog('Catalog-v3.xml', false, @user, @options)

      # Original subscription is grandfathered
      add_days_and_check_invoice_item(30, 3, 'basic-monthly', '2013-10-01', '2013-11-01', 1000.0)

      # The annual plan is only present in the v3 catalog
      create_basic_entitlement(4, 'ANNUAL', '2013-10-01', '2014-10-01', 14000.0)

      add_days_and_check_invoice_item(31, 5, 'basic-monthly', '2013-11-01', '2013-12-01', 1000.0)
    end

    # Remove a phase in a subsequent catalog
    def test_remove_phase
      upload_catalog('Catalog-WithTrial.xml', false, @user, @options)

      # The first subscription has a trial phase
      create_basic_entitlement(1, 'MONTHLY', '2013-08-01', nil, 0.0)

      # Move the clock to 2013-08-15
      add_days(14)

      # Effective date of the second catalog is 2013-08-15
      upload_catalog('Catalog-NoTrial.xml', false, @user, @options)

      # The new subscription doesn't have a trial phase
      # Because of the ACCOUNT billing alignment, there is a leading proration
      create_basic_entitlement(2, 'MONTHLY', '2013-08-15', '2013-08-31', 516.13)

      # Move the clock to 2013-08-31 (30 days trial)
      add_days(16)

      invoice = check_invoice_balance(3, '2013-08-31', 2000.0)
      check_invoice_item(invoice.items[0], invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(invoice.items[1], invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Move the clock to 2013-09-30
      add_days(30)

      invoice = check_invoice_balance(4, '2013-09-30', 2000.0)
      check_invoice_item(invoice.items[0], invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-09-30', '2013-10-31')
      check_invoice_item(invoice.items[1], invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-09-30', '2013-10-31')
    end

    def test_create_alignment
      upload_catalog('Catalog-CreateAlignment.xml', false, @user, @options)

      bp = create_basic_entitlement(1, 'MONTHLY', '2013-08-01', nil, 0.0)

      # Move the clock to 2013-08-15
      add_days(14)

      # Add a first add-on with a START_OF_BUNDLE creation alignment. The subscription is aligned
      # with the bundle creation date (2013-08-01) meaning the trial will be from 2013-08-15 to 2013-08-31
      create_ao_entitlement(bp, 2, 'BasicAOStartOfBundle', 'MONTHLY', '2013-08-15', 0)

      # Add a second add-on with a START_OF_SUBSCRIPTION creation alignment. The subscription is aligned
      # with the add-on subscription creation date (2013-08-15) meaning the trial will be from 2013-08-15 to 2013-09-14
      create_ao_entitlement(bp, 3, 'BasicAOStartOfSubscription', 'MONTHLY', '2013-08-15', 0)

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

    def test_change_alignment_start_of_bundle
      bp, ao = setup_change_alignment_test

      # Change plan with a start of bundle change alignment: the trial will still end on 2013-08-31
      change_ao_entitlement(ao, 3, 'BasicAOStartOfBundle', 'MONTHLY', '2013-08-05', 0.0, '2013-08-15')
      check_subscription_events(bp,
                                ao,
                                [{:type => 'START_ENTITLEMENT', :date => '2013-08-01'},
                                 {:type => 'START_BILLING', :date => '2013-08-01'},
                                 {:type => 'PHASE', :date => '2013-08-31'}],
                                [{:type => 'START_ENTITLEMENT', :date => '2013-08-05'},
                                 {:type => 'START_BILLING', :date => '2013-08-05'},
                                 {:type => 'CHANGE', :date => '2013-08-15'},
                                 {:type => 'PHASE', :date => '2013-08-31'}])

      # Move the clock to 2013-08-31 (30 days trial)
      add_days(16)

      # Both subscriptions are aligned on the same invoice (ACCOUNT billing alignment)
      invoice = check_invoice_balance(4, '2013-08-31', 1100.0)
      check_invoice_item(invoice.items[0], invoice.invoice_id, 100.0, 'USD', 'RECURRING', 'BasicAOStartOfBundle-monthly', 'BasicAOStartOfBundle-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(invoice.items[1], invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-31', '2013-09-30')
    end

    def test_change_alignment_start_of_subscription
      bp, ao = setup_change_alignment_test

      # Change plan with a start of subscription change alignment: the trial will now end on 2013-09-04
      change_ao_entitlement(ao, 3, 'BasicAOStartOfSubscription', 'MONTHLY', '2013-08-05', 0.0, '2013-08-15')
      check_subscription_events(bp,
                                ao,
                                [{:type => 'START_ENTITLEMENT', :date => '2013-08-01'},
                                 {:type => 'START_BILLING', :date => '2013-08-01'},
                                 {:type => 'PHASE', :date => '2013-08-31'}],
                                [{:type => 'START_ENTITLEMENT', :date => '2013-08-05'},
                                 {:type => 'START_BILLING', :date => '2013-08-05'},
                                 {:type => 'CHANGE', :date => '2013-08-15'},
                                 {:type => 'PHASE', :date => '2013-09-04'}])

      # Move the clock to 2013-08-31 (30 days trial)
      add_days(16)

      invoice = check_invoice_balance(4, '2013-08-31', 1000.0)
      check_invoice_item(invoice.items[0], invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Move the clock to 2013-09-04
      add_days(4)

      # Pro-rated invoice for the add-on (ACCOUNT billing alignment)
      invoice = check_invoice_balance(5, '2013-09-04', 125.81)
      check_invoice_item(invoice.items[0], invoice.invoice_id, 125.81, 'USD', 'RECURRING', 'BasicAOStartOfSubscription-monthly', 'BasicAOStartOfSubscription-monthly-evergreen', '2013-09-04', '2013-09-30')

      # Move the clock to 2013-09-30
      add_days(26)

      invoice = check_invoice_balance(6, '2013-09-30', 1150.0)
      check_invoice_item(invoice.items[0], invoice.invoice_id, 150.0, 'USD', 'RECURRING', 'BasicAOStartOfSubscription-monthly', 'BasicAOStartOfSubscription-monthly-evergreen', '2013-09-30', '2013-10-31')
      check_invoice_item(invoice.items[1], invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-09-30', '2013-10-31')
    end

    def test_change_alignment_change_of_plan
      bp, ao = setup_change_alignment_test

      # Change plan with a start of change of plan change alignment: the trial will now end on 2013-09-14
      change_ao_entitlement(ao, 3, 'BasicAOChangeOfPlan', 'MONTHLY', '2013-08-05', 0.0, '2013-08-15')
      check_subscription_events(bp,
                                ao,
                                [{:type => 'START_ENTITLEMENT', :date => '2013-08-01'},
                                 {:type => 'START_BILLING', :date => '2013-08-01'},
                                 {:type => 'PHASE', :date => '2013-08-31'}],
                                [{:type => 'START_ENTITLEMENT', :date => '2013-08-05'},
                                 {:type => 'START_BILLING', :date => '2013-08-05'},
                                 {:type => 'CHANGE', :date => '2013-08-15'},
                                 {:type => 'PHASE', :date => '2013-09-14'}])

      # Move the clock to 2013-08-31 (30 days trial)
      add_days(16)

      invoice = check_invoice_balance(4, '2013-08-31', 1000.0)
      check_invoice_item(invoice.items[0], invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Move the clock to 2013-09-14
      add_days(14)

      # Pro-rated invoice for the add-on (ACCOUNT billing alignment)
      invoice = check_invoice_balance(5, '2013-09-14', 103.23)
      check_invoice_item(invoice.items[0], invoice.invoice_id, 103.23, 'USD', 'RECURRING', 'BasicAOChangeOfPlan-monthly', 'BasicAOChangeOfPlan-monthly-evergreen', '2013-09-14', '2013-09-30')

      # Move the clock to 2013-09-30
      add_days(16)

      invoice = check_invoice_balance(6, '2013-09-30', 1200.0)
      check_invoice_item(invoice.items[0], invoice.invoice_id, 200.0, 'USD', 'RECURRING', 'BasicAOChangeOfPlan-monthly', 'BasicAOChangeOfPlan-monthly-evergreen', '2013-09-30', '2013-10-31')
      check_invoice_item(invoice.items[1], invoice.invoice_id, 1000.0, 'USD', 'RECURRING', 'basic-monthly', 'basic-monthly-evergreen', '2013-09-30', '2013-10-31')
    end

    #def test_change_alignment_change_of_pricelist
    #  # TODO This hasn't been implemented yet in Kill Bill
    #end

    def test_create_simple_plan
      add_catalog_simple_plan("basic-annual", "Basic", 'USD', 10000.00, "ANNUAL", 0, "UNLIMITED", @user, @options)

      catalogs = get_tenant_catalog('2013-02-09', @options)
      assert_equal(1, catalogs.size)
      catalog = catalogs[0]

      assert_equal(1, catalog.price_lists.size)
      assert_equal(2, catalog.price_lists[0]['plans'].size)
      assert_equal("basic-monthly", catalog.price_lists[0]['plans'][0])
      assert_equal("basic-annual", catalog.price_lists[0]['plans'][1])

      assert_equal(1, catalog.products.size)
      assert_equal(2, catalog.products[0].plans.size)

      assert_equal("basic-annual", catalog.products[0].plans[1].name)
      assert_equal(1, catalog.products[0].plans[1].phases.size)
    end


    private

    # This will:
    #   * create a bundle on 2013-08-01 (30 days trial)
    #   * add an add-on on 2013-08-05 (30 days trial)
    #   * move the clock to 2013-08-15
    # test_change_alignment_* tests will then change the add-on plan using different alignments
    def setup_change_alignment_test
      upload_catalog('Catalog-ChangeAlignment.xml', false, @user, @options)

      bp = create_basic_entitlement(1, 'MONTHLY', '2013-08-01', nil, 0.0)

      # Move the clock to 2013-08-05
      add_days(4)

      ao = create_ao_entitlement(bp, 2, 'BasicAO', 'MONTHLY', '2013-08-05', 0.0)
      check_subscription_events(bp,
                                ao,
                                [{:type => 'START_ENTITLEMENT', :date => '2013-08-01'},
                                 {:type => 'START_BILLING', :date => '2013-08-01'},
                                 {:type => 'PHASE', :date => '2013-08-31'}],
                                [{:type => 'START_ENTITLEMENT', :date => '2013-08-05'},
                                 {:type => 'START_BILLING', :date => '2013-08-05'},
                                 {:type => 'PHASE', :date => '2013-08-31'}])

      # Move the clock to 2013-08-15
      add_days(10)

      [bp, ao]
    end

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

    def create_ao_entitlement(bp, invoice_nb, product, billing_period='MONTHLY', start_date='2013-08-01', amount=1000.0, invoice_date=start_date)
      ao = create_entitlement_ao(@account.account_id, bp.bundle_id, product, billing_period, 'DEFAULT', @user, @options)
      check_subscription(ao, product, 'ADD_ON', billing_period, 'DEFAULT', start_date, nil, start_date, nil)
      check_fixed_item(invoice_nb, product + '-' + billing_period.downcase, invoice_date, amount, start_date)
      ao
    end

    def change_ao_entitlement(ao, invoice_nb, product, billing_period='MONTHLY', ao_start_date='2013-08-01', amount=0.0, invoice_date=start_date)
      ao = ao.change_plan({:productName => product, :billingPeriod => billing_period, :priceList => 'DEFAULT'}, @user, nil, nil, nil, nil, false, @options)
      check_subscription(ao, product, 'ADD_ON', billing_period, 'DEFAULT', ao_start_date, nil, ao_start_date, nil)
      check_fixed_item(invoice_nb, product + '-'+ billing_period.downcase, invoice_date, amount)
    end

    def check_subscription_events(bp, ao, bp_events, ao_events)
      # Check bundle subscriptions
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      # Check base plan events
      bps = subscriptions.reject { |s| s.product_category == 'ADD_ON' }
      assert_not_nil(bps)
      assert_equal(1, bps.size)
      check_events(bp_events, bps[0].events)

      # Check add-on events
      aos = subscriptions.reject { |s| s.product_category == 'BASE' }
      assert_not_nil(aos)
      assert_equal(1, aos.size)
      check_events(ao_events, aos[0].events)

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
      check_next_invoice_amount(invoice_nb, amount, invoice_date, @account, @options, &@proc_account_invoices_nb)[-1]
    end
  end
end
