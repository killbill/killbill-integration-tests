$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestCloud < Base

    def setup
      setup_base

      catalog_file_xml = get_resource_as_string("usage/cloud.xml")
      KillBillClient::Model::Catalog.upload_tenant_catalog(catalog_file_xml, @user, 'New Catalog Version', 'Upload catalog for tenant', @options)

      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
      end

    NB_USAGE_TYPES = 3
    MAX_SERVERS_PER_TYPE = 10
    USAGE_MIN = 0
    USAGE_MAX = 24 * MAX_SERVERS_PER_TYPE


    def test_demo_with_multiple_units


      #
      # Step 1. Create a subscription associated with the account `@account` 
      #
      bp = create_entitlement_base(@account.account_id, 'Server', 'MONTHLY', 'DEFAULT', @user, @options)
      # Test waits synchronously until the first invoice was generated ($0 invoice since no usage was recorded yet)
      wait_for_expected_clause(1, @account, @options, &@proc_account_invoices_nb)


      # Step 2. Record usage: For each usage type, we generate random usage value per day, each point between [USAGE_MIN, USAGE_MAX)
      usage_input = []
      expected_dollar_amount_total = 0
      expected_dollar_amount_per_unit = {}
      NB_USAGE_TYPES.times do |i|

        raw_usage = generate_random_usage_values(8, 2013, USAGE_MIN, USAGE_MAX)
        expected_usage_unit_amount = raw_usage.inject(0) { |sum, e| sum += e }
        # Price for unit 1 is $1, price for unit 2 is $2, ...
        expected_dollar_amount_per_unit[i] = expected_usage_unit_amount * (i + 1)

        expected_dollar_amount_total += expected_dollar_amount_per_unit[i]

        usage_input << {:unit_type => "server-hourly-type-#{i + 1}",
                        :usage_records => generate_usage_for_each_day(8, 2013, raw_usage)
        }

      end
      #
      # Make the call to record the usage (POST /1.0/kb/usages).
      #
      # We make one bulk call to record all the points for all usage types in the month, but we could
      # also make one call per day, and/or one call per unit type per day...
      #
      record_usage(bp.subscription_id, usage_input, @user, @options)


      #
      # Step 3. Move the clock to the beginning of the next month '2013-09-01' to trigger the first invoice with usage items
      #
      kb_clock_add_days(31, nil, @options)
      wait_for_expected_clause(2, @account, @options, &@proc_account_invoices_nb)

      #
      # Verify we see an invoice with:
      # * 3 usage items (one for each type) for the previous month (in arrear usage billing)
      # * 1 recurring item of $0 for the next month
      #
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      last_invoice = all_invoices[1]
      check_invoice_no_balance(last_invoice, expected_dollar_amount_total, 'USD', '2013-09-01')
      check_invoice_item(last_invoice.items[0], last_invoice.invoice_id, 0.0, 'USD', 'RECURRING', 'server-monthly', 'server-monthly-evergreen', '2013-09-01', '2013-10-01')

      check_usage_invoice_item(last_invoice.items[1], last_invoice.invoice_id, expected_dollar_amount_per_unit[2], 'USD', 'USAGE', 'server-monthly', 'server-monthly-evergreen', 'server-monthly-usage-type-3', '2013-08-01', '2013-09-01')
      check_usage_invoice_item(last_invoice.items[2], last_invoice.invoice_id, expected_dollar_amount_per_unit[1], 'USD', 'USAGE', 'server-monthly', 'server-monthly-evergreen', 'server-monthly-usage-type-2', '2013-08-01', '2013-09-01')
        check_usage_invoice_item(last_invoice.items[3], last_invoice.invoice_id, expected_dollar_amount_per_unit[0], 'USD', 'USAGE', 'server-monthly', 'server-monthly-evergreen', 'server-monthly-usage-type-1', '2013-08-01', '2013-09-01')

    end


    def test_with_multiple_units


      bps = []
      nb_subscriptions = 100
      nb_subscriptions.times do |i|
        bp = create_entitlement_base(@account.account_id, 'Server', 'MONTHLY', 'DEFAULT', @user, @options)
        wait_for_expected_clause(i + 1, @account, @options, &@proc_account_invoices_nb)
        bps << bp
      end



      expected_usage_unit_amount_for_bps = {}
      bps.each do |bp|


        usage_input = []

        bp_expected_usage_unit_amount = 0

        3.times do |i|

          raw_usage = generate_random_usage_values(8, 2013, 0, 178)
          expected_usage_unit_amount = raw_usage.inject(0) { |sum, e| sum += e}
          expected_usage_unit_amount = expected_usage_unit_amount * (i + 1)

          bp_expected_usage_unit_amount += expected_usage_unit_amount

          usage_input << {:unit_type => "server-hourly-type-#{i + 1}",
                          :usage_records => generate_usage_for_each_day(8, 2013, raw_usage)
          }

        end

        expected_usage_unit_amount_for_bps[bp.subscription_id] = bp_expected_usage_unit_amount
        record_usage(bp.subscription_id, usage_input, @user, @options)

      end

      all_expected_usage_unit_amount = expected_usage_unit_amount_for_bps.values.inject(0) { |sum, e| sum += e }

      kb_clock_add_days(31, nil, @options)
      wait_for_expected_clause(nb_subscriptions + 1, @account, @options, &@proc_account_invoices_nb)

      all_invoices = @account.invoices(true, @options)

      puts "all_invoices  = #{all_invoices.size}"

      sort_invoices!(all_invoices)
      assert_equal(nb_subscriptions + 1, all_invoices.size)
      last_invoice = all_invoices[nb_subscriptions]
      check_invoice_no_balance(last_invoice, all_expected_usage_unit_amount, 'USD', '2013-09-01')
      check_invoice_item(last_invoice.items[0], last_invoice.invoice_id, 0.0, 'USD', 'RECURRING', 'server-monthly', 'server-monthly-evergreen', '2013-09-01', '2013-10-01')
    end


    private

    COMMON_YEAR_DAYS_IN_MONTH = [nil, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    def days_in_month(month, year)
      return 29 if month == 2 && Date.gregorian_leap?(year)
      COMMON_YEAR_DAYS_IN_MONTH[month]
    end

    def generate_random_usage_values(month, year, min_included, max_excluded)
      res = []
      nb_values = days_in_month(month, year)
      nb_values.times { |i| res << rand(min_included...max_excluded) }
      res
    end

    def generate_usage_for_each_day(month, year, raw_usage)
      res= []
      raw_usage.inject(1) do |day, e|
        new_value = {}
        new_value[:record_date] = day < 10 ? "#{year.to_s}-#{month.to_s}-0#{day}" : "#{year.to_s}-#{month.to_s}-#{day}"
        new_value[:amount] = e
        res << new_value
        day +=1
      end
      res
    end


  end
end
