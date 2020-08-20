# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../mixin-utils', __dir__)
$LOAD_PATH.unshift File.expand_path(__dir__)

require 'thread/pool'

require 'killbill_client'
require 'helper'
require 'load_base'

module KillBillIntegrationTests
  NB_THREADS = 1
  NB_ITERATIONS = 1

  WITH_STATS = true

  load_pool = LoadPool.new(NB_THREADS, NB_ITERATIONS, WITH_STATS)

  test_task = LoadTask.new(load_pool.pool,
                           :Test,
                           proc do |iteration|
                             test_task.with_rescue_and_timing(iteration) do |options|
                               test_task.op_kb_clock_get(nil, options)
                             end
                           end, false, WITH_STATS)
  load_pool.add_task(test_task, 1)

  auth_capture_task = LoadTask.new(load_pool.pool,
                                   :AuthCapture,
                                   proc do |iteration|
                                     auth_capture_task.with_rescue_and_timing(iteration) do |options|
                                       account = auth_capture_task.setup_account(options)
                                       auth = auth_capture_task.op_create_auth(account.account_id, auth_capture_task.gen_key, auth_capture_task.gen_key, '34.76', account.currency, auth_capture_task.name, options)
                                       auth_capture_task.op_create_capture(auth.payment_id, auth_capture_task.gen_key, '34.76', account.currency, auth_capture_task.name, options)
                                       # payments = auth_capture_task.get_payments_for_account(account.account_id, options)
                                     end
                                   end, false, WITH_STATS)
  load_pool.add_task(auth_capture_task, 1)

  auth_with_error_task = LoadTask.new(load_pool.pool,
                                      :AuthError,
                                      proc do |iteration|
                                        auth_with_error_task.with_rescue_and_timing(iteration) do |options|
                                          account = auth_with_error_task.setup_account(options)
                                          auth_with_error_task.add_property('THROW_EXCEPTION', 'unknown', options)
                                          auth = auth_with_error_task.op_create_auth(account.account_id, auth_with_error_task.gen_key, auth_with_error_task.gen_key, '34.76', account.currency, auth_with_error_task.name, options)
                                        end
                                      end, true, WITH_STATS)
  load_pool.add_task(auth_with_error_task, 10)

  purchase_multiple_refunds_task = LoadTask.new(load_pool.pool,
                                                :PurchaseMultipleRefunds,
                                                proc do |iteration|
                                                  purchase_multiple_refunds_task.with_rescue_and_timing(iteration) do |options|
                                                    account = purchase_multiple_refunds_task.setup_account(options)

                                                    purchase = purchase_multiple_refunds_task.op_create_purchase(account.account_id, purchase_multiple_refunds_task.gen_key, purchase_multiple_refunds_task.gen_key, '20.40', account.currency, purchase_multiple_refunds_task.name, options)
                                                    purchase_multiple_refunds_task.op_create_refund(purchase.payment_id, purchase_multiple_refunds_task.gen_key, '10.20', account.currency, purchase_multiple_refunds_task.name, options)
                                                    purchase_multiple_refunds_task.op_create_refund(purchase.payment_id, purchase_multiple_refunds_task.gen_key, '10.20', account.currency, purchase_multiple_refunds_task.name, options)
                                                  end
                                                end, false, WITH_STATS)
  load_pool.add_task(purchase_multiple_refunds_task, 5)

  credit_task = LoadTask.new(load_pool.pool,
                             :Credit,
                             proc do |iteration|
                               credit_task.with_rescue_and_timing(iteration) do |options|
                                 account = credit_task.setup_account(options)
                                 credit = credit_task.op_create_credit(account.account_id, credit_task.gen_key, credit_task.gen_key, '34.76', account.currency, credit_task.name, options)
                               end
                             end, false, WITH_STATS)
  load_pool.add_task(credit_task, 5)

  auth_multi_capture_task = LoadTask.new(load_pool.pool,
                                         :AuthMultiCapture,
                                         proc do |iteration|
                                           auth_multi_capture_task.with_rescue_and_timing(iteration) do |options|
                                             account = auth_multi_capture_task.setup_account(options)

                                             auth = auth_multi_capture_task.op_create_auth(account.account_id, auth_multi_capture_task.gen_key, auth_multi_capture_task.gen_key, '10.0', account.currency, auth_multi_capture_task.name, options)

                                             auth_multi_capture_task.op_create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.op_create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.op_create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.op_create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.op_create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.op_create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.op_create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                           end
                                         end, false, WITH_STATS)
  load_pool.add_task(auth_multi_capture_task, 5)

  load_pool.run_tasks

  load_pool.report(NB_THREADS)
end
