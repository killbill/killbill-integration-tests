# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../mixin-utils', __dir__)

require 'thread/pool'

require 'killbill_client'
require 'helper'

#
# Add statistical functions
#
module Enumerable
  #  sum of an array of numbers
  def sum
    inject(0) { |acc, i| acc + i }
  end

  #  average of an array of numbers
  def average
    sum / length.to_f
  end

  #  variance of an array of numbers
  def sample_variance
    avg = average
    sum = inject(0) { |acc, i| acc + (i - avg)**2 }
    (1 / length.to_f * sum)
  end

  #  standard deviation of an array of numbers
  def standard_deviation
    Math.sqrt(sample_variance)
  end

  def percentile(percentile = 0.0)
    sort[(length * percentile).ceil - 1]
  end
end

module KillBillIntegrationTests
  class LoadTask
    include Helper

    KillBillClient.url = 'http://127.0.0.1:8080'

    attr_reader :name, :op_stats, :tasks_stats, :profiling_stats, :exceptions

    def initialize(pool, name, proc_task, expect_exception = false, with_stats = true)
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
    def with_rescue_and_timing(_iteration)
      before_task = Time.now

      per_thread_profiling_data = {}
      begin
        options = { username: 'admin', password: 'password', profilingData: per_thread_profiling_data }
        yield(options)
      rescue StandardError => e
        unless @expect_exception
          puts "Task #{@name} got an unexpected exception #{e}"
          @exceptions << e
        end
      ensure
        if @with_stats
          after_task = Time.now
          @mutex_stats.synchronize do
            @tasks_stats << (after_task - before_task)

            per_thread_profiling_data.each do |k, v|
              @profiling_stats[k] = [] if @profiling_stats[k].nil?
              (@profiling_stats[k] << v).flatten!
            end
          end
        end
      end
    end

    def add_property(key, value, options)
      prop_test_mode = KillBillClient::Model::PluginPropertyAttributes.new
      prop_test_mode.key = key
      prop_test_mode.value = value
      options[:pluginProperty] = [] if options[:pluginProperty].nil?
      options[:pluginProperty] << prop_test_mode
    end

    def setup_account(options)
      account = op_create_account(@name, options)
      op_add_payment_method(account.account_id, 'killbill-payment-test', true, nil, @name, options)
      add_property('TEST_MODE', 'CONTROL', options)
      account
    end

    def gen_key(nb_char = 15)
      rand(36**nb_char).to_s(36)
    end

    # Overload
    def method_missing(method, *args)
      if method.to_s.start_with?('assert_')
        # Ignore
      elsif method.to_s.start_with?('op_')
        dispatch_op method.to_s[3, method.to_s.length].to_sym, *args
      else
        raise "Missing method #{method}"
      end
    end

    private

    def format_ms(stat_sec)
      return '???' if stat_sec.nil?

      r = format('%.2f', (stat_sec * 1000))
      "#{r} ms"
    end

    def dispatch_op(method, *args)
      begin
        result = send method, *args
      rescue StandardError => e
        raise e
      ensure
      end
      result
    end
  end

  class LoadPool
    attr_reader :pool, :payment_tasks, :task_ratios, :nb_iterations, :with_stats

    def initialize(nb_threads, nb_iterations, with_stats = true)
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
      (1..@nb_iterations).each do |i|
        @task_ratios.each do |task_name, modulo|
          if i % modulo == 0
            @payment_tasks[task_name].run(i)
            @nb_tasks += 1
          end
        end
      end

      # wait for all tasks to be processed
      @pool.shutdown
      @end_time = Time.now
    end

    def format_stat_usec(value)
      return format_string('???', 16) if value.nil?

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
          puts "TASK #{task_name} (iterations = #{task.tasks_stats.size}, err = #{task.exceptions.size}) avg = #{format_stat_usec(task.tasks_stats.average)} min = #{format_stat_usec(task.tasks_stats.min)} max = #{format_stat_usec(task.tasks_stats.max)} tp90 = #{format_stat_usec(task.tasks_stats.percentile(0.9))} std = #{format_stat_usec(task.tasks_stats.standard_deviation)}"
          data.merge!(task.profiling_stats) { |_k, o, n| (o << n).flatten! }
        end

        return if data.empty?

        puts "\nOperations:"

        data = Hash[data.sort_by { |_k, v| v.percentile(0.9).to_f }]

        max_len_op = (data.keys.map(&:size).max || 0) + 1
        data.each do |k, v|
          puts "#{format_string("#{k}:", max_len_op)} avg = #{format_stat_usec(v.average)} min = #{format_stat_usec(v.min)} max = #{format_stat_usec(v.max)} tp90 = #{format_stat_usec(v.percentile(0.9))} std = #{format_stat_usec(v.standard_deviation)}"
        end
      end
    end
  end
end
