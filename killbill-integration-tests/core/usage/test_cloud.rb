$LOAD_PATH.unshift File.expand_path('../../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestCloud < Base

    def setup
      setup_base

      upload_catalog("usage/Cloud.xml", false, @user, @options)

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
      #
      all_invoices = @account.invoices(true, @options)
      sort_invoices!(all_invoices)
      assert_equal(2, all_invoices.size)
      last_invoice = all_invoices[1]
      check_invoice_no_balance(last_invoice, expected_dollar_amount_total, 'USD', '2013-09-01')

      if aggregate_mode?
        check_usage_invoice_item(find_usage_ii('server-monthly-usage-type-3', last_invoice.items), last_invoice.invoice_id, expected_dollar_amount_per_unit[2], 'USD', 'USAGE', 'server-monthly', 'server-monthly-evergreen', 'server-monthly-usage-type-3', '2013-08-01', '2013-09-01')
        check_usage_invoice_item(find_usage_ii('server-monthly-usage-type-2', last_invoice.items), last_invoice.invoice_id, expected_dollar_amount_per_unit[1], 'USD', 'USAGE', 'server-monthly', 'server-monthly-evergreen', 'server-monthly-usage-type-2', '2013-08-01', '2013-09-01')
        check_usage_invoice_item(find_usage_ii('server-monthly-usage-type-1', last_invoice.items), last_invoice.invoice_id, expected_dollar_amount_per_unit[0], 'USD', 'USAGE', 'server-monthly', 'server-monthly-evergreen', 'server-monthly-usage-type-1', '2013-08-01', '2013-09-01')

        check_invoice_consumable_item_detail(find_usage_ii('server-monthly-usage-type-3', last_invoice.items),
                                             [{:tier => 1, :unit_type => 'server-hourly-type-3', :unit_qty => find_quantity(usage_input,'server-hourly-type-3' ), :tier_price => 3.0 }], expected_dollar_amount_per_unit[2])
        check_invoice_consumable_item_detail(find_usage_ii('server-monthly-usage-type-2', last_invoice.items),
                                             [{:tier => 1, :unit_type => 'server-hourly-type-2', :unit_qty => find_quantity(usage_input,'server-hourly-type-2' ), :tier_price => 2.0 }], expected_dollar_amount_per_unit[1])
        check_invoice_consumable_item_detail(find_usage_ii('server-monthly-usage-type-1', last_invoice.items),
                                             [{:tier => 1, :unit_type => 'server-hourly-type-1', :unit_qty => find_quantity(usage_input,'server-hourly-type-1' ), :tier_price => 1.0 }], expected_dollar_amount_per_unit[0])
      else
        check_usage_invoice_item_w_quantity(find_usage_ii('server-monthly-usage-type-3', last_invoice.items), last_invoice.invoice_id, expected_dollar_amount_per_unit[2], 'USD', 'USAGE', 'server-monthly', 'server-monthly-evergreen', 'server-monthly-usage-type-3', '2013-08-01', '2013-09-01', 3.0, find_quantity(usage_input,'server-hourly-type-3' ))
        check_usage_invoice_item_w_quantity(find_usage_ii('server-monthly-usage-type-2', last_invoice.items), last_invoice.invoice_id, expected_dollar_amount_per_unit[1], 'USD', 'USAGE', 'server-monthly', 'server-monthly-evergreen', 'server-monthly-usage-type-2', '2013-08-01', '2013-09-01', 2.0, find_quantity(usage_input,'server-hourly-type-2' ))
        check_usage_invoice_item_w_quantity(find_usage_ii('server-monthly-usage-type-1', last_invoice.items), last_invoice.invoice_id, expected_dollar_amount_per_unit[0], 'USD', 'USAGE', 'server-monthly', 'server-monthly-evergreen', 'server-monthly-usage-type-1', '2013-08-01', '2013-09-01', 1.0, find_quantity(usage_input,'server-hourly-type-1' ))
      end
    end


    private

    def find_quantity(usage_input, usage_name)
      quantity = 0
      usage = usage_input.select { |input| input[:unit_type] == usage_name }.first
      usage[:usage_records].each { |record| quantity += record[:amount] }
      quantity
    end

    def find_usage_ii(usage_name, items)
      filtered = items.select do |ii|
        ii.usage_name == usage_name && ii.item_type == 'USAGE'
      end
      assert_equal(1, filtered.size)
      return filtered[0]
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

    COMMON_YEAR_DAYS_IN_MONTH = [nil, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    def days_in_month(month, year)
      return 29 if month == 2 && Date.gregorian_leap?(year)
      COMMON_YEAR_DAYS_IN_MONTH[month]
    end

  end
end
