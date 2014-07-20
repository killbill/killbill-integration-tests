$LOAD_PATH.unshift File.expand_path('../../mixin-utils', __FILE__)


require 'thread'
require 'thread/pool'

require 'killbill_client'
require 'helper'

module KillBillIntegrationTests


  class LoadTask

    include Helper

    KillBillClient.url = 'http://127.0.0.1:8080'

    attr_reader :name

    def initialize(pool, name, proc_task)
      @pool = pool
      @name = name
      @proc_task = proc_task
    end

    def run(iteration)
      @pool.process(iteration, &@proc_task)
    end

    def add_property(key, value, options)
      prop_test_mode = KillBillClient::Model::PluginPropertyAttributes.new
      prop_test_mode.key = key
      prop_test_mode.value = value
      options[:pluginProperty] = [] if  options[:pluginProperty].nil?
      options[:pluginProperty] << prop_test_mode
    end

    def setup_account(options)
      account = create_account(@name, nil, options)
      add_payment_method(account.account_id, 'killbill-payment-test', true, @name, options)
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
      else
        raise RuntimeError.new("Missing method #{method.to_s}")
      end
    end
  end


  class LoadPool

    attr_reader :pool, :payment_tasks, :task_ratios, :nb_iterations

    def initialize(nb_threads, nb_iterations)
      @pool = Thread.pool(nb_threads)
      @payment_tasks = {}
      @task_ratios = {}
      @nb_iterations = nb_iterations
    end

    def add_task(task, ratio)
      @payment_tasks[task.name] = task
      @task_ratios[task.name] = ratio
    end

    def run_tasks

      nb_tasks = 0

      prev = Time.now
      for i in (1..@nb_iterations) do
        @task_ratios.each do |task_name, modulo|
          if (i % modulo == 0)
            @payment_tasks[task_name].run(i)
            nb_tasks = nb_tasks + 1
          end
        end
      end

      # wait for all tasks to be processed
      @pool.shutdown

      elapsed = Time.now - prev
      puts "Elapsed = #{elapsed} => Tasks/sec = #{nb_tasks / elapsed.to_f}"
    end
  end

end

