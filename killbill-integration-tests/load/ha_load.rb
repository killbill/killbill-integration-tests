$LOAD_PATH.unshift File.expand_path('../../mixin-utils', __FILE__)
$LOAD_PATH.unshift File.expand_path('../', __FILE__)

require 'thread'
require 'thread/pool'

require 'concurrent/array'

require 'killbill_client'
require 'helper'
require 'load_base'

require 'test_base'

module KillBillIntegrationTests

  class TestHA < Base

    NB_THREADS = 5

    # Number of parents
    NB_ITERATIONS = 1
    NB_CHILDREN_PER_PARENT = 50

    # Number of parent or child accounts to verify at each run (we don't verify all of them, as it would take too long)
    SAMPLE_SIZE_TO_VERIFY = 10

    WITH_STATS = false

    def setup
      @options = {
          :username => ENV['USERNAME'] || 'admin',
          :password => ENV['PASSWORD'] || 'password',
          :api_key => ENV['API_KEY'] || 'bob',
          :api_secret => ENV['API_SECRET'] || 'lazar',
          :timeout_sec => 90,
          :read_timeout => 90000
      }

      @user = 'ha_load'

      @parents = Concurrent::Array.new
      @children = Concurrent::Array.new
    end

    def test_invoice_generation
      load_pool = LoadPool.new(NB_THREADS, NB_ITERATIONS, WITH_STATS)

      create_parent_children_task = LoadTask.new(load_pool.pool,
                                                 :CreateParentChildren,
                                                 Proc.new do |iteration|
                                                   create_parent_children_task.with_rescue_and_timing(iteration) do |raw_options|
                                                     options = raw_options.merge(@options)

                                                     parent = create_parent_children_task.op_create_account(@user, options)
                                                     @parents << parent
                                                     1.upto(NB_CHILDREN_PER_PARENT) do |_|
                                                       child = create_parent_children_task.op_create_account_with_data(@user,
                                                                                                                       {
                                                                                                                           :parent_account_id => parent.account_id,
                                                                                                                           :is_payment_delegated_to_parent => true,
                                                                                                                           :bill_cycle_day_local => 14
                                                                                                                       },
                                                                                                                       options)
                                                       @children << child

                                                       create_parent_children_task.create_entitlement_base(child.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
                                                     end
                                                   end
                                                 end,
                                                 false,
                                                 WITH_STATS)
      load_pool.add_task(create_parent_children_task, 1)

      kb_clock_set('2015-01-15', nil, @options)
      load_pool.run_tasks

      puts "Created #{@parents.size} parents and #{@children.size} children"

      # 2015-01-15
      verify_all_invoices(0, 1, 1)
      # 2015-01-16
      generate_invoices(DateTime.new(2015, 1, 16, 0, 15, 0).to_s)
      verify_all_invoices(1, 0, 1)

      # We add 15 minutes to make sure we process all notifications
      init_date = DateTime.new(2015, 1, 14, 0, 15, 0)
      1.upto(24) do |i|
        # Generate children invoices
        generate_invoices((init_date >> i).to_s)
        verify_all_invoices(i, 1, i + 1)

        # Commit parent invoice (next day)
        generate_invoices(((init_date >> i) + 1).to_s)
        verify_all_invoices(i + 1, 0, i + 1)
      end
    end

    private

    def generate_invoices(date)
      t1 = Time.now
      kb_clock_set(date, nil, @options)
      t2 = Time.now
      puts "#{date} Invoice generation took #{t2 - t1}s"
    end

    def verify_all_invoices(nb_committed_each_parent,
                            nb_draft_each_parent,
                            nb_committed_each_child,
                            nb_draft_each_child = 0)
      load_pool = LoadPool.new(NB_THREADS, 1, WITH_STATS)

      @children.sample(SAMPLE_SIZE_TO_VERIFY).each do |child|
        verify_child_invoices_task = LoadTask.new(load_pool.pool,
                                                  "VerifyChildInvoices_#{child.account_id}",
                                                  Proc.new do |iteration|
                                                    verify_child_invoices_task.with_rescue_and_timing(iteration) do |_|
                                                      all_invoices = child.invoices(false, @options)
                                                      nb_committed_invoices, nb_draft_invoices = count_invoices_by_status(all_invoices)
                                                      assert_equal(nb_committed_each_child, nb_committed_invoices, "Mismatch for childAccountId=#{child.account_id}, expected #{nb_committed_each_child} COMMITTED, got #{nb_committed_invoices}")
                                                      assert_equal(nb_draft_each_child, nb_draft_invoices, "Mismatch for childAccountId=#{child.account_id}, expected #{nb_draft_each_child} DRAFT, got #{nb_draft_invoices}")
                                                      assert_equal(nb_committed_each_child + nb_draft_each_child, all_invoices.size)
                                                    end
                                                  end,
                                                  false,
                                                  false)
        load_pool.add_task(verify_child_invoices_task, 1)
      end

      @parents.sample(SAMPLE_SIZE_TO_VERIFY).each do |parent|
        verify_parent_invoices_task = LoadTask.new(load_pool.pool,
                                                   "VerifyParentInvoices_#{parent.account_id}",
                                                   Proc.new do |iteration|
                                                     verify_parent_invoices_task.with_rescue_and_timing(iteration) do |_|
                                                       all_invoices = parent.invoices(false, @options)
                                                       nb_committed_invoices, nb_draft_invoices = count_invoices_by_status(all_invoices)
                                                       assert_equal(nb_committed_each_parent, nb_committed_invoices, "Mismatch for parentAccountId=#{parent.account_id}, expected #{nb_committed_each_parent} COMMITTED, got #{nb_committed_invoices}")
                                                       assert_equal(nb_draft_each_parent, nb_draft_invoices, "Mismatch for parentAccountId=#{parent.account_id}, expected #{nb_draft_each_parent} DRAFT, got #{nb_draft_invoices}")
                                                       assert_equal(nb_committed_each_parent + nb_draft_each_parent, all_invoices.size)
                                                     end
                                                   end,
                                                   false,
                                                   WITH_STATS)
        load_pool.add_task(verify_parent_invoices_task, 1)
      end

      load_pool.run_tasks

      load_pool.payment_tasks.values.each { |t| assert_equal(0, t.exceptions.size) }
    end

    def count_invoices_by_status(all_invoices)
      nb_committed_invoices = 0
      nb_draft_invoices = 0
      all_invoices.each do |invoice|
        invoice.status == 'DRAFT' ? nb_draft_invoices += 1 : nb_committed_invoices += 1
      end
      [nb_committed_invoices, nb_draft_invoices]
    end
  end
end
