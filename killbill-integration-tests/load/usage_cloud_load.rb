$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestCloud < Base

    def setup
      setup_base
      catalog_file_xml = get_resource_as_string("usage/Cloud.xml")
      KillBillClient::Model::Catalog.upload_tenant_catalog(catalog_file_xml, @user, 'New Catalog Version', 'Upload catalog for tenant', @options)
    end

    def teardown
      teardown_base
      end

    NB_USAGE_TYPES = 3
    MAX_SERVERS_PER_TYPE = 10
    USAGE_MIN = 0
    USAGE_MAX = 24 * MAX_SERVERS_PER_TYPE

    NB_ACCOUNTS_PER_DAY = 3
    NB_SUBSCRIPTIONS_PER_ACCOUNT = 3


    def test_with_accounts_subscriptions_units

      nb_account_per_day = NB_ACCOUNTS_PER_DAY
      nb_subscriptions_per_account = NB_SUBSCRIPTIONS_PER_ACCOUNT

      #
      # Initialize by creating `nb_account_per_day`  with each `nb_subscriptions_per_account`
      # As we create the accounts we add random usage each day for subscriptions created and keep track of the usage
      #
      all_accounts = initialize_all_account_with_usage_data(nb_account_per_day, nb_subscriptions_per_account)

      #
      # At run through a few months and each day:
      # 1. verify the new invoices generated (By checking $ amount matches what we created)
      # 2. keep adding usage for all subscriptions on each day
      #
      prev_nb_day_in_month = 31
      gen_month_year_entries(9, 2013, 12).each_with_index do |month_year, idx|

        month = month_year[0]
        year = month_year[1]

        cur_nb_day_in_month = days_in_month(month, year)
        cur_nb_day_in_month.times do |zero_based_day|

          kb_clock_add_days(1, nil, @options)

          day = zero_based_day + 1
          date = format_date(day, month, year)

          puts "*** [#{date}]: NEXT ITERATION..."

          verify_invoices_for_account_range_and_reset_usage(all_accounts, zero_based_day, 0, month, year, nb_account_per_day, nb_subscriptions_per_account, idx)

          # There is a little bit of complexity to take care of the shorter months and make sure that for instance accounts created on the 31 will correctly be checked
          # in months with 30 days and their counter will be reset to 0 , so next month, the invoice check still works!
          #
          if prev_nb_day_in_month && cur_nb_day_in_month == zero_based_day + 1 && cur_nb_day_in_month < prev_nb_day_in_month
            (prev_nb_day_in_month-cur_nb_day_in_month).times do |catch_up_idx|
              verify_invoices_for_account_range_and_reset_usage(all_accounts, zero_based_day, (catch_up_idx + 1), month, year, nb_account_per_day, nb_subscriptions_per_account, idx)
            end
          end

          add_usage_to_existing_subscriptions(all_accounts, year, month, zero_based_day + 1)

        end

        prev_nb_day_in_month = cur_nb_day_in_month
      end
    end



    def add_usage_to_existing_subscriptions(all_accounts, year, month, day)

      all_accounts.each do |account_entry|

        additional_per_account_usage = 0

        # For each subscription record some rabndom usage data
        account_entry[:bps].each do |bp|

          usage_input = []
          NB_USAGE_TYPES.times do |i|

            # Generate random amount of usage data
            raw_usage_amount = rand(USAGE_MIN...USAGE_MAX)
            # To compute the price we know that unit 1 => $1, unit 2 => $2, unit 3 => $3, hence the multiplication with (i + 1)
            additional_per_account_usage += raw_usage_amount * (i + 1)
            usage_input << {
                :unit_type => "server-hourly-type-#{i + 1}",
                :usage_records => [{:record_date => format_date(day, month, year), :amount => raw_usage_amount}]
            }
          end
          # Record usage on that day for that subscription (all 3 units in one call)
          record_usage(bp.subscription_id, usage_input, @user, @options)
        end
        # Keep track of usage so we can't verify the price of the invoice generated
        account_entry[:usage] = account_entry[:usage].nil? ? additional_per_account_usage : account_entry[:usage] + additional_per_account_usage
      end
    end



    def create_new_account_with_subscriptions(nb_accounts, nb_subscriptions_per_account)

      accounts = []
      # Create all he accounts for that day
      nb_accounts.times do |nb|
        account = create_account(@user, @options)
        bps = []
        # For each account create the subscriptions
        nb_subscriptions_per_account.times do |i|
          bp = create_entitlement_base(account.account_id, 'Server', 'MONTHLY', 'DEFAULT', @user, @options)
          # We expect one invoice per subscription created
          wait_for_expected_clause(i + 1, account, @options, &@proc_account_invoices_nb)
          bps << bp
        end
        # Keep track of the created accounts along with its subscriptions
        accounts << { :account => account, :bps => bps}
      end
      accounts
    end

    def initialize_all_account_with_usage_data(nb_account_per_day, nb_subscriptions_per_account)

      # Clock has been initialized at 2013-08-01
      year = 2013
      month = 8

      all_accounts = []
      # For each day of the month we create the accounts/subscriptions and start inserting usage data
      days_in_month(month, year).times do |zero_based_day|

        day = zero_based_day + 1
        date = format_date(day, month, year)
        puts "*** [#{date}]: CREATE #{nb_account_per_day} ACCOUNT(S) WITH #{nb_subscriptions_per_account} SUBSCRIPTION(S)"

        all_accounts << create_new_account_with_subscriptions(nb_account_per_day, nb_subscriptions_per_account)
        all_accounts.flatten!

        add_usage_to_existing_subscriptions(all_accounts, year, month, (zero_based_day + 1))

        puts "*** [#{date}]: ADDING USAGE TO SUBSCRIPTIONS..."
        kb_clock_add_days(1, nil, @options) if zero_based_day < 30
      end
      all_accounts
    end

    def verify_invoices_for_account_range_and_reset_usage(all_accounts, zero_based_day, catch_up_end_of_month_idx, month, year, nb_account_per_day, nb_subscriptions_per_account, month_idx)

      day = zero_based_day + 1
      date = format_date(day, month, year)

      account_idx = zero_based_day + catch_up_end_of_month_idx
      #
      # For each day, we should have as many new invoices as we created accounts on that day, so we extract the range of accounts that match that day
      # (along with catch up days that don't exist in that specific months as indicated by catch_up_end_of_month_idx)
      #
      all_accounts[account_idx*nb_account_per_day..((account_idx+1)*nb_account_per_day)-1].each do |account_entry|
        puts "*** [#{date}]: WAITING FOR INVOICES FOR ACCOUNT #{account_entry[:account].account_id}"

        # Verify new invoice got created
        expected_number_invoices = nb_subscriptions_per_account + (month_idx + 1)
        wait_for_expected_clause(expected_number_invoices, account_entry[:account], @options, &@proc_account_invoices_nb)

        all_invoices = account_entry[:account].invoices(true, @options)
        sort_invoices!(all_invoices)
        assert_equal(expected_number_invoices, all_invoices.size)
        last_invoice = all_invoices[expected_number_invoices - 1]

        # Verify balance in that invoice based on what we computed internally
        check_invoice_no_balance(last_invoice, account_entry[:usage], 'USD', format_date(day, month, year))
          # Reset entry to prepare for accrual in the next rolling month
        account_entry[:usage] = 0
      end

    end


    private

    COMMON_YEAR_DAYS_IN_MONTH = [nil, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    def days_in_month(month, year)
      return 29 if month == 2 && Date.gregorian_leap?(year)
      COMMON_YEAR_DAYS_IN_MONTH[month]
    end

    def format_date(day, month, year)
      day_str = day < 10 ? "0#{day}" : "#{day}"
      month_str = month < 10 ? "0#{month}" : "#{month}"
      "#{year.to_s}-#{month_str}-#{day_str}"
    end


    def gen_month_year_entries(init_month, init_year, nb_months)
      result = []
      cur_month = init_month
      cur_year = init_year
      nb_months.times do |idx|
        result << [cur_month, cur_year]
        cur_month = cur_month < 12 ? cur_month + 1 : 1
        cur_year = cur_month == 1 ? cur_year + 1 : cur_year
      end
      result
    end

  end
end
