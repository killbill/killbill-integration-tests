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
end

module KillBillIntegrationTests


  class LoadTask

    include Helper

    #KillBillClient.url = 'http://killbill-uat2.snc1:8080'
    KillBillClient.url = 'http://127.0.0.1:8080'

    attr_reader :name, :op_stats, :tasks_stats, :exceptions

    def initialize(pool, name, proc_task, expect_exception=false)
      @pool = pool
      @name = name
      @proc_task = proc_task
      @expect_exception = expect_exception
      @op_stats = {}
      @tasks_stats = []
      @exceptions = []
      @stat_mutex = Mutex.new
    end

    def run(iteration)
      @pool.process(iteration, &@proc_task)
    end

    def with_rescue_and_timing(iteration)
      before_task = Time.now
      begin
        #puts "Running iteration #{@name} : #{iteration}"
        yield
      rescue => e
        if !@expect_exception
          puts "Task #{@name} got an unexpected exception #{e.to_s}"
          @exceptions << e
        end
      ensure
        after_task = Time.now
        @tasks_stats << (after_task - before_task)
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

    def report
      puts "TASK #{@name} (iterations = #{@tasks_stats.size}) err = #{@exceptions.size} : avg = #{format_ms(@tasks_stats.average)}, min = #{format_ms(@tasks_stats.min)}, max = #{format_ms(@tasks_stats.max)}, std = #{format_ms(@tasks_stats.standard_deviation)}"
      op_stats.each do |k, v|
        puts "\t OP #{k} : avg = #{format_ms(v.average)}, min = #{format_ms(v.min)}, max = #{format_ms(v.max)}, std = #{format_ms(v.standard_deviation)}"
      end
      puts "\n"
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

      before_op = Time.now
      after_op = nil
      begin
        result = send method, *args
      rescue => e
        raise e
      ensure
        after_op = Time.now
        @stat_mutex.synchronize {
          op_result = @op_stats[method]
          if op_result.nil?
            op_result = []
            @op_stats[method] = op_result
          end
          op_result << (after_op - before_op)
        }
      end

      result
    end
  end


  class LoadPool

    attr_reader :pool, :payment_tasks, :task_ratios, :nb_iterations

    def initialize(nb_threads, nb_iterations)
      @pool = Thread.pool(nb_threads)
      @payment_tasks = {}
      @task_ratios = {}
      @nb_iterations = nb_iterations
      @start_time = nil
      @end_time = nil
      @nb_tasks = 0
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

    def report(nb_threads)

      puts "########################################  REPORT nb_threads = #{nb_threads} ################################\n"
      payment_tasks.each do |k, v|
        v.report
      end

      puts
      elapsed = @end_time - @start_time
      puts "########################################  TOTAL TIME = #{elapsed} => Tasks/sec = #{'%.2f' % (@nb_tasks / elapsed.to_f)}  ############################\n"

    end
  end

end

