$LOAD_PATH.unshift File.expand_path('../../mixin-utils', __FILE__)


require 'thread'
require 'thread/pool'

require 'killbill_client'
require 'helper'

#
# Add statistical functions
#
module Enumerable

  #  sum of an array of numbers
  def sum
    return self.inject(0) { |acc, i| acc + i }
  end

  #  average of an array of numbers
  def average
    return self.sum / self.length.to_f
  end

  #  variance of an array of numbers
  def sample_variance
    avg = self.average
    sum = self.inject(0) { |acc, i| acc + (i - avg)**2 }
    return(1 / self.length.to_f*sum)
  end

  #  standard deviation of an array of numbers
  def standard_deviation
    return Math.sqrt(self.sample_variance)
  end

  def percentile(percentile=0.0)
    self.sort[((self.length * percentile).ceil)-1]
  end
end

module KillBillIntegrationTests


  class LoadTask

    include Helper

    #KillBillClient.url = 'http://killbill-uat2.snc1:8080'
    KillBillClient.url = 'http://127.0.0.1:8080'

    attr_reader :name, :op_stats, :tasks_stats, :profiling_stats, :exceptions

    def initialize(pool, name, proc_task, expect_exception=false, with_stats=true)
      @pool = pool
      @name = name
      @proc_task = proc_task
      @expect_exception = expect_exception
      @exceptions = []

      @with_stats = with_stats
      @tasks_stats = []
      @profiling_stats = {}

      @mutex_stats = Mutex.new
    end

    def run(iteration)
      @pool.process(iteration, &@proc_task)
    end

    #
    # Wrapper around the task proc to extract profiling info
    # (Note that we make use of the server side profiling data by passing the option :profilingData)
    #
    def with_rescue_and_timing(iteration)

      before_task = Time.now

      per_thread_profiling_data = {}
      begin
        options = {:username => 'admin', :password => 'password', :profilingData => per_thread_profiling_data}
        yield(options)
      rescue => e
        if !@expect_exception
          puts "Task #{@name} got an unexpected exception #{e.to_s}"
          @exceptions << e
        end
      ensure
        if @with_stats
          after_task = Time.now
          @mutex_stats.synchronize {

            @tasks_stats << (after_task - before_task)

            per_thread_profiling_data.each do |k, v|
              if @profiling_stats[k].nil?
                @profiling_stats[k] = []
              end
              (@profiling_stats[k] << v).flatten!
            end
          }
        end
      end
    end

    def add_property(key, value, options)
      prop_test_mode = KillBillClient::Model::PluginPropertyAttributes.new
      prop_test_mode.key = key
      prop_test_mode.value = value
      options[:pluginProperty] = [] if  options[:pluginProperty].nil?
      options[:pluginProperty] << prop_test_mode
    end

    def setup_account(options)
      account = op_create_account(@name, nil, options)
      op_add_payment_method(account.account_id, 'killbill-payment-test', true, @name, options)
      add_property('TEST_MODE', 'CONTROL', options)
      account
    end

    def gen_key(nb_char=15)
      rand(36**nb_char).to_s(36)
    end

    # Overload
    def method_missing(method, *args, &proc)
      if method.to_s.start_with?('assert_')
        # Ignore
      elsif method.to_s.start_with?('op_')
        dispatch_op method.to_s[3, method.to_s.length].to_sym, *args
      else
        raise RuntimeError.new("Missing method #{method.to_s}")
      end
    end

    private

    def format_ms(stat_sec)
      if stat_sec.nil?
        return "???"
      end
      r = '%.2f' % (stat_sec * 1000)
      "#{r.to_s} ms"
    end

    def dispatch_op(method, *args)

      begin
        result = send method, *args
      rescue => e
        raise e
      ensure
      end
      result
    end
  end


  class LoadPool

    attr_reader :pool, :payment_tasks, :task_ratios, :nb_iterations, :with_stats

    def initialize(nb_threads, nb_iterations, with_stats=true)
      @pool = Thread.pool(nb_threads)
      @payment_tasks = {}
      @task_ratios = {}
      @nb_iterations = nb_iterations
      @start_time = nil
      @end_time = nil
      @nb_tasks = 0
      @with_stats = with_stats
    end

    def add_task(task, ratio)
      @payment_tasks[task.name] = task
      @task_ratios[task.name] = ratio
    end

    def run_tasks

      @start_time = Time.now
      for i in (1..@nb_iterations) do
        @task_ratios.each do |task_name, modulo|
          if (i % modulo == 0)
            @payment_tasks[task_name].run(i)
            @nb_tasks = @nb_tasks + 1
          end
        end
      end

      # wait for all tasks to be processed
      @pool.shutdown
      @end_time = Time.now
    end

    def format_stat_usec(value)
      return format_string("???", 16) if value.nil?
      format_string(('%.2f' % value.to_f).to_s, 16)
    end

    def format_string(input, max_len)
      "%-#{max_len}s" % input
    end

    def report(nb_threads)

      puts "**************************    COMPLETED LOAD TESTS (nbThreads = #{nb_threads})    ***************************"

      if @with_stats
        data = {}
        @payment_tasks.each do |task_name, task|
          puts "TASK #{task_name} (iterations = #{task.tasks_stats.size}) err = #{task.exceptions.size}"
          data.merge!(task.profiling_stats) { |k, o, n| (o << n).flatten! }
        end

        puts "\nOperations:"


        max_len_op = data.keys.map { |k| k.size}.sort.last + 1
        data.each do |k, v|
          puts "#{format_string("#{k}:", max_len_op)} avg = #{format_stat_usec(v.average)} min = #{format_stat_usec(v.min)} max = #{format_stat_usec(v.max)} tp90 = #{format_stat_usec(v.percentile(0.9))} std = #{format_stat_usec(v.standard_deviation)}"
        end
      end
    end
  end
end

