$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('..', __FILE__)

require 'concurrent'
require 'date'
require 'faker'
require 'logger'
require 'logger_colored'

require 'seed_base'

module Faker
  class Base
    class << self
      def fetch(key, options = {})
        fetched = translate("faker.#{key}", options)
        fetched = fetched.sample if fetched.respond_to?(:sample)
        if fetched.match(/^\//) and fetched.match(/\/$/) # A regex
          regexify(fetched)
        else
          fetched
        end
      end
    end
  end
end


module KillBillIntegrationSeed
  class TestSeedKaui < TestSeedBase

    def setup
      log_dir = '/var/tmp/'
      now = Time.now.strftime('%Y-%m-%d-%H:%M')
      kb_log_path = "#{log_dir}/kaui_seed.#{now}.killbill.log"
      KillBillClient.logger = Logger.new(kb_log_path)
      KillBillClient.logger.level = Logger::DEBUG

      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO

      @pool = Concurrent::CachedThreadPool.new

      @base_subscriptions = Concurrent::Array.new
      @ao_subscriptions = Concurrent::Hash.new
      @subs_mutex = Mutex.new

      tenant_info = {
          :use_multi_tenant => true,
          :api_key => ENV['api_key'] || 'bob',
          :api_secret => ENV['api_secret'] || 'lazar'
      }

      @start_date = ENV['start_date'] || Date.today.to_s
      setup_base('kaui_seed', tenant_info, "#{@start_date}T08:00:00.000Z", ENV['kb_host'] || DEFAULT_KB_ADDRESS, ENV['kb_port'] || DEFAULT_KB_PORT)
      upload_catalog(ENV['catalog'], true, @user, @options) if ENV['catalog']
    end

    def teardown
      @pool.shutdown
      teardown_base
    end

    def test_seed_kaui
      initial_date = DateTime.parse(@start_date).to_date
      last_date = DateTime.now.to_date

      run_with_clock(initial_date, last_date) { |date| run_one_day(date) }
    end

    private

    def run_one_day(date)
      # Notes:
      # * The config is global, so set it before creating accounts in parallel
      # * Stick to a few "safe" locales (rather than sampling I18n.available_locales) to ensure having enough data in Faker
      Faker::Config.locale = [:de, :en, :es, :fa, :fr, :it, :ja, :ko, :ru].sample

      task = lambda { create_account_with_subscription }
      nb_accounts = case date.wday
                      when 0 then # Sunday
                        rand(0..2)
                      when 1..5 then
                        rand(3..8)
                      else # Saturday
                        rand(2..5)
                    end

      @logger.info "Creating #{nb_accounts} accounts on #{date.to_s} (locale #{Faker::Config.locale})"
      run_in_parallel(nb_accounts, task)

      # Trigger a few cancellations
      task = lambda { cancel_random_subscription }
      nb_cancellations = (nb_accounts * 20 / 100.0).to_i
      run_in_parallel(nb_cancellations == 0 ? 2 : nb_cancellations, task)
    end

    def create_account_with_subscription(nb_retries = 3)
      account = create_account
      create_payment_method(account)

      base = create_base_subscription(account)
      create_add_on(account, base)
    rescue => e
      raise e if nb_retries <= 0

      # Maybe we generated random data which a plugin didn't support, or we got an exception with Faker and obscure locales
      @logger.warn "Exception when generating data #{e.message}, trying again..."
      create_account_with_subscription(nb_retries - 1)
    end

    def create_account
      first_name = Faker::Name.first_name
      last_name = Faker::Name.last_name
      data = {
          :name => "#{first_name} #{last_name}",
          :first_name_length => first_name.length,
          :external_key => Faker::Code.npi,
          :email => Faker::Internet.email,
          :locale => Faker::Config.locale,
          # Limited by the catalog
          :currency => %w(USD GBP EUR).sample,
          :phone => Faker::PhoneNumber.phone_number,
          # We don't want the timezone to be translated
          :time_zone => Faker::Address.fetch('address.time_zone', {:locale => :en}),
          :address1 => Faker::Address.street_address,
          :address2 => Faker::Address.secondary_address,
          :postal_code => Faker::Address.postcode,
          :city => Faker::Address.city,
          :state => Faker::Address.state,
          :country => Faker::Address.country_code,
          :company => "#{Faker::Company.name}: #{Faker::Company.catch_phrase}"[0..49]
      }
      account = create_account_with_data(@user, data, @options)
      @logger.info "Created account #{account.account_id}: #{account.name}"

      account
    end

    def create_payment_method(account)
      # Faker::Finance.credit_card doesn't seem to produce only valid ones
      cc_nums = {
          'visa' => 4111111111111111,
          'master' => 5555555555554444,
          'american_express' => 378282246310005
      }
      cc_type = cc_nums.keys.sample

      expiry_date = Faker::Business.credit_card_expiry_date

      plugin_info = {
          'ccNumber' => cc_nums[cc_type],
          'ccExpirationMonth' => expiry_date.month,
          'ccExpirationYear' => expiry_date.year,
          'ccVerificationValue' => '723',
          'ccFirstName' => Faker::Name.first_name,
          'ccLastName' => Faker::Name.last_name,
          'ccType' => cc_type,
          # CyberSource is really picky about emails
          'email' => Faker::Internet.free_email('john'),
          'address1' => Faker::Address.street_address,
          'city' => Faker::Address.city,
          'state' => Faker::Address.state,
          'zip' => Faker::Address.postcode,
          'country' => Faker::Address.country_code
      }

      @logger.debug "Plugin info: #{plugin_info}"

      add_payment_method(account.account_id, ENV['payment_plugin'] || 'killbill-stripe', true, plugin_info, @user, @options)
    end

    def create_base_subscription(account)

      product, billing_period, price_list = case rand(10)
                                             when 0..4 then
                                               ['reserved-metal', 'MONTHLY', 'TRIAL']
                                             when 5 then
                                               ['reserved-metal', 'ANNUAL', 'DEFAULT']
                                             when 6..8 then
                                               ['reserved-vm', 'MONTHLY', 'TRIAL']
                                             else
                                               ['on-demand-metal', 'NO_BILLING_PERIOD', 'DEFAULT']
                                           end

      base = create_entitlement_base(account.account_id, product, billing_period, price_list, @user, @options)
      @logger.info "Created #{product.downcase}-#{billing_period.downcase}-#{price_list} subscription for account id #{account.account_id}"

      @base_subscriptions << base

      base
    end

    def create_add_on(account, base)
      # Not available

      @logger.info "create_add_on: base = #{base.inspect}"

      return if base.product_name != 'reserved-vm' || base.price_list != 'TRIAL'

      ao_product = 'backup-daily'
      return ao_product

      # Only monthly add-ons are supported
      billing_period = 'MONTHLY'

      ao = create_entitlement_ao(account.account_id, base.bundle_id, ao_product, billing_period, 'DEFAULT', @user, @options)
      @logger.info "Created #{ao_product.downcase}-#{billing_period.downcase} subscription for account id #{account.account_id}"

      @ao_subscriptions[base.bundle_id] ||= []
      @ao_subscriptions[base.bundle_id] << ao

      ao
    end

    def cancel_random_subscription
      # Wait to have created enough subscriptions
      return if @base_subscriptions.size < 100

      sub = @subs_mutex.synchronize do
        # Assume most of the cancellations are for add-ons
        if rand(10) > 3
          if  ! @ao_subscriptions.empty?
            bundle_id = @ao_subscriptions.keys.sample
            sub = @ao_subscriptions[bundle_id].shuffle.pop
          end
        else
          sub = @base_subscriptions.shuffle.pop
          @ao_subscriptions.delete(sub.bundle_id)
        end
        sub
      end

      # Use default policies
      sub.cancel(@user, nil, nil, nil, nil, nil, nil, @options)
      @logger.info "Cancelled #{sub.product_name}-#{sub.billing_period.downcase} subscription for account id #{sub.account_id}"
    end

    def run_in_parallel(nb_times, task)
      return if nb_times == 0
      latch = Concurrent::CountDownLatch.new(nb_times)

      nb_times.times do
        @pool.post do
          begin
            task.call
          rescue => e
            @logger.warn "Exception in task: #{e.message}\n#{e.backtrace.join("\n")}"
          ensure
            latch.count_down
          end
        end
      end

      latch.wait
      wait_for_killbill(@options) rescue nil
    end

    # We ignore timeouts here, to make sure we always advance the clock
    def run_with_clock(initial_date, last_date)
      date = initial_date.prev_day
      kb_clock_set("#{date.to_s}T08:00:00.000Z", nil, @options) rescue nil

      while date <= last_date do
        @logger.info "Moving clock to #{date.next_day}"
        kb_clock_add_days(1, nil, @options) rescue nil

        yield date if block_given?

        date = date.next_day
      end
    end

    def wait_for_killbill(options)
      super(options, {:timeoutSec => 30})
    end
  end
end
