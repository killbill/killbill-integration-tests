$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('..', __FILE__)

require 'concurrent'
require 'date'
require 'logger'
require 'test_base'

#
#
#
module KillBillIntegrationTests

  class TestInvoiceGeneration < KillBillIntegrationTests::Base

    def setup

      setup_logger

      parse_envs

      @pool = Concurrent::CachedThreadPool.new

      tenant_info = {:use_multi_tenant => true,
                     #:create_multi_tenant => true,
                     :api_key => @api_key,
                     :api_secret => @api_secret}


      setup_base('test_invoice_iteration', tenant_info, "#{@start_date}T08:00:00.000Z", @kb_host, @kb_port)
      upload_catalog(@catalog, true, @user, @options) if @catalog
    end

    def teardown
      @pool.shutdown
      teardown_base
    end

    def test_invoice

      # Infinite loop
      i = 1
      begin
        test_invoice_iteration(i)
        i += 1
      end until false
    end

    private


    def parse_envs

      @kb_host = ENV['kb_host'] || DEFAULT_KB_ADDRESS
      @kb_port = ENV['kb_port'] || DEFAULT_KB_PORT

      @api_key = ENV['api_key'] || 'invoice'
      @api_secret = ENV['api_secret'] || 'invoice'

      @nb_accounts = ENV['nb_accounts'] ? ENV['nb_accounts'].to_i : 10
      @sleep_time =  ENV['sleep_time'] ?  ENV['sleep_time'].to_f : nil
      @start_date = ENV['start_date'] || Date.today.to_s
      @subscription_create_delay = ENV['subscription_create_delay'] ? ENV['subscription_create_delay'].to_i : nil

      @catalog = ENV['catalog']

      @logger.info "Starting TestInvoiceGeneration @nb_accounts=#{@nb_accounts}, @start_date=#{@start_date}, @kb_host=#{@kb_host}, @kb_port=#{@kb_port}, @api_key=#{@api_key}, @catalog=#{@catalog}, @sleep_time=#{@sleep_time}, @subscription_create_delay=#{@subscription_create_delay}"

    end


    def test_invoice_iteration(i)

      setup_logger unless i == 1

      initial_date = DateTime.parse(@start_date).to_date

      task = lambda { create_account_with_subscription(initial_date) }

      @logger.info "Iteration #{i} : Creating #{@nb_accounts} accounts on #{initial_date.to_s}"
      run_in_parallel(@nb_accounts, task)
    end


    def setup_logger
      log_dir = '/var/tmp/'
      now = Time.now.strftime('%Y-%m-%d-%H:%M')
      kb_log_path = "#{log_dir}/invoice.#{now}.killbill.log"
      kb_log_client_path = "#{log_dir}/invoice.#{now}.client.log"

      KillBillClient.logger = Logger.new(kb_log_client_path)
      KillBillClient.logger.level = Logger::WARN

      @logger = Logger.new(kb_log_path)
      @logger.level = Logger::INFO
    end

    def create_account_with_subscription(date, nb_retries = 1)

      sleep @sleep_time unless @sleep_time.nil?

      # Create account
      account = create_account
      # set AUTO_PAY_OFF
      account.set_auto_pay_off(@user, nil, nil, @options)
      # create a base subscription
      base = create_base_subscription(date, account)
    rescue => e
      raise e if nb_retries <= 0
      @logger.warn "Exception when generating data #{e.message}, trying again..."
      create_account_with_subscription(date, nb_retries - 1)
    end

    def create_account
      account = create_account_with_data(@user, {}, @options)
      @logger.info "Created account #{account.account_id}: #{account.name}"
      account
    end

    def create_base_subscription(date, account)
      product = case rand(10)
                  when 0..5 then
                    'Standard'
                  when 6..8 then
                    'Sports'
                  else
                    'Super'
                end

      billing_period = 'MONTHLY'

      requested_date = @subscription_create_delay.nil? ? date : date + @subscription_create_delay

      base = create_entitlement_base_with_date(account.account_id, product, billing_period, 'DEFAULT', requested_date, @user, @options)
      @logger.info "Created #{product.downcase}-#{billing_period.downcase} subscription for account id #{account.account_id} on date #{requested_date}"
      base
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

    def wait_for_killbill(options)
      super(options, {:timeoutSec => 30})
    end
  end
end
