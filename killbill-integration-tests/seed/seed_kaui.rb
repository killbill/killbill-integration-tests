# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift File.expand_path(__dir__)

require 'date'
require 'faker'
require 'logger'
require 'logger_colored'

require 'seed_base'

# To avoid certain translations
module Faker
  class Base
    class << self
      def fetch(key, options = {})
        fetched = translate("faker.#{key}", options)
        fetched = fetched.sample if fetched.respond_to?(:sample)
        if fetched.match(%r{^/}) && fetched.match(%r{/$}) # A regex
          regexify(fetched)
        else
          fetched
        end
      end
    end
  end
end

# Generate seed data (using SpyCarAdvanced catalog and Stripe plugin by default)
module KillBillIntegrationSeed
  class TestSeedKaui < TestSeedBase
    def setup
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO

      # KillBillClient.logger = @logger

      @base_subscriptions = Concurrent::Array.new
      @ao_subscriptions = Concurrent::Hash.new

      tenant_info = {
        use_multi_tenant: true,
        # create_multi_tenant: true,
        api_key: ENV['API_KEY'] || 'bob',
        api_secret: ENV['API_SECRET'] || 'lazar'
      }

      @start_date = ENV['START_DATE'] || (Date.today << 6).to_s # 6 months of data by default
      setup_base('kaui_seed', tenant_info, "#{@start_date}T08:00:00.000Z", ENV['KB_HOST'] || DEFAULT_KB_ADDRESS, ENV['KB_PORT'] || DEFAULT_KB_PORT)
      upload_catalog('SpyCarAdvanced.xml', true, @user, @options)
    end

    def teardown
      teardown_base
    end

    def test_seed_kaui
      initial_date = DateTime.parse(@start_date).to_date
      last_date = DateTime.now.to_date

      run_with_clock(initial_date, last_date) { |date| run_one_day(date) }
    end

    private

    def run_one_day(date)
      nb_accounts = case date.wday
                    when 0 # Sunday
                      rand(0..2)
                    when 1..5
                      rand(3..8)
                    else # Saturday
                      rand(2..5)
                    end

      @logger.info "Creating #{nb_accounts} accounts on #{date}"

      1.upto(nb_accounts) do |_|
        # Notes:
        # * The config is global
        # * Stick to a few "safe" locales (rather than sampling I18n.available_locales) to ensure having enough data in Faker
        Faker::Config.locale = %i[de en es fr it].sample
        create_account_with_subscription(0)
      end

      # Trigger a few cancellations
      nb_cancellations = (nb_accounts * 60 / 100.0).to_i
      0.upto(nb_cancellations) do |_|
        cancel_random_subscription
      end
    end

    def create_account_with_subscription(nb_retries = 3)
      account = create_account
      create_payment_method(account)

      base = create_base_subscription(account)
      create_add_on(account, base)
    rescue StandardError => e
      raise e if nb_retries <= 0

      # Maybe we generated random data which a plugin didn't support, or we got an exception with Faker and obscure locales
      @logger.warn "Exception when generating data #{e.message}, trying again..."
      create_account_with_subscription(nb_retries - 1)
    end

    def create_account
      first_name = Faker::Name.first_name
      last_name = Faker::Name.last_name
      data = {
        name: "#{first_name} #{last_name}",
        first_name_length: first_name.length,
        external_key: Faker::Code.npi,
        email: Faker::Internet.email,
        locale: Faker::Config.locale,
        # Limited by the catalog
        currency: %w[USD GBP EUR].sample,
        phone: Faker::PhoneNumber.phone_number,
        # We don't want the timezone to be translated
        time_zone: Faker::Address.fetch('address.time_zone', { locale: :en }),
        address1: Faker::Address.street_address,
        address2: Faker::Address.secondary_address,
        postal_code: Faker::Address.postcode,
        city: Faker::Address.city,
        state: Faker::Address.state,
        country: Faker::Address.country_code,
        company: "#{Faker::Company.name}: #{Faker::Company.catch_phrase}"[0..49]
      }
      account = create_account_with_data(@user, data, @options)
      @logger.info "Created account #{account.account_id}: #{account.name}"

      account
    end

    def create_payment_method(account)
      # Faker::Finance.credit_card doesn't seem to produce only valid ones
      cc_nums = {
        'visa' => 4_111_111_111_111_111,
        'master' => 5_555_555_555_554_444,
        'american_express' => 378_282_246_310_005
      }
      cc_type = cc_nums.keys.sample

      expiry_date = Faker::Business.credit_card_expiry_date

      stripe_token = case rand(10)
                     when 0..2
                       'tok_visa'
                     when 3..4
                       'tok_mastercard'
                     when 5
                       'tok_amex'
                     else
                       'tok_chargeCustomerFail'
                     end
      plugin_info = {
        'token' => stripe_token,
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

      add_payment_method(account.account_id, ENV['PAYMENT_PLUGIN'] || 'killbill-stripe', true, plugin_info, @user, @options)
    end

    def create_base_subscription(account)
      product, billing_period, price_list = case rand(10)
                                            when 0..4 then
                                              %w[Sports MONTHLY DEFAULT]
                                            when 5 then
                                              %w[Sports ANNUAL DEFAULT]
                                            when 6..8 then
                                              %w[Standard MONTHLY SpecialDiscount]
                                            else
                                              %w[Standard ANNUAL DEFAULT]
                                            end

      base = create_entitlement_base(account.account_id, product, billing_period, price_list, @user, @options)
      @logger.info "Created #{product.downcase}-#{billing_period.downcase}-#{price_list} subscription for account id #{account.account_id}"

      @base_subscriptions << base

      base
    end

    def create_add_on(account, base)
      return if base.product_name != 'Sports'

      ao_product = case rand(10)
                   when 0..4
                     nil
                   when 5..7
                     'OilSlick'
                   else
                     'RemoteControl'
                   end
      return if ao_product.nil?

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
      # return if @base_subscriptions.size < 100

      # Assume most of the cancellations are for add-ons
      sub = nil
      if rand(10) > 3
        unless @ao_subscriptions.empty?
          bundle_id = @ao_subscriptions.keys.sample
          sub = @ao_subscriptions[bundle_id].shuffle!.pop
        end
      else
        sub = @base_subscriptions.shuffle!.pop
        @ao_subscriptions.delete(sub.bundle_id)
      end

      return if sub.nil?

      # Use default policies
      sub.cancel(@user, nil, nil, nil, nil, nil, nil, @options)
      @logger.info "Cancelled #{sub.product_name}-#{sub.billing_period.downcase} subscription for account id #{sub.account_id}"
    end

    # We ignore timeouts here, to make sure we always advance the clock
    def run_with_clock(initial_date, last_date)
      date = initial_date
      begin
        kb_clock_set("#{date}T08:00:00.000Z", nil, @options)
      rescue StandardError
        nil
      end

      while date <= last_date
        yield date if block_given?

        @logger.info "Moving clock to #{date.next_day}"
        begin
          kb_clock_add_days(1, nil, @options)
        rescue StandardError
          nil
        end

        date = date.next_day
      end
    end
  end
end
