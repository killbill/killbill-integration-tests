$LOAD_PATH.unshift File.expand_path('../../mixin-utils', __FILE__)


require 'thread'
require 'thread/pool'

require 'killbill_client'
require 'helper'
require 'load_base'

module KillBillIntegrationTests


  NB_THREADS = 10
  NB_ITERATIONS = 10

  load_pool = LoadPool.new(NB_THREADS, NB_ITERATIONS)

  auth_capture_task = LoadTask.new(load_pool.pool,
                                   :AuthCapture,
                                   Proc.new do |iteration|
                                     begin
                                       puts "Running iteration #{auth_capture_task.name} : #{iteration}"
                                       options = {:username => 'admin', :password => 'password'}
                                       account = auth_capture_task.setup_account(options)
                                       auth = auth_capture_task.create_auth(account.account_id, auth_capture_task.gen_key, auth_capture_task.gen_key, '34.76', account.currency, auth_capture_task.name, options)
                                       auth_capture_task.create_capture(auth.payment_id, auth_capture_task.gen_key, '34.76', account.currency, auth_capture_task.name, options)
                                         #payments = auth_capture_task.get_payments_for_account(account.account_id, options)
                                     rescue => e
                                       puts "Task #{auth_capture_task.name} got an exception #{e.to_s}"
                                     end
                                   end)
  load_pool.add_task(auth_capture_task, 1)

  auth_with_error_task = LoadTask.new(load_pool.pool,
                                      :AuthError,
                                      Proc.new do |iteration|
                                        begin
                                          puts "Running iteration #{auth_with_error_task.name} : #{iteration}"
                                          options = {:username => 'admin', :password => 'password'}
                                          account = auth_with_error_task.setup_account(options)

                                          auth_with_error_task.add_property('THROW_EXCEPTION', 'unknown', options)
                                          auth = auth_with_error_task.create_auth(account.account_id, auth_with_error_task.gen_key, auth_with_error_task.gen_key, '34.76', account.currency, auth_with_error_task.name, options)
                                            #payments = auth_with_error_task.get_payments_for_account(account.account_id, options)
                                        rescue => e
                                          puts "Task #{auth_with_error_task.name} got an exception #{e.to_s}"
                                        end
                                      end)
  load_pool.add_task(auth_with_error_task, 10)

  purchase_multiple_refunds_task = LoadTask.new(load_pool.pool,
                                                :PurchaseMultipleRefunds,
                                                Proc.new do |iteration|
                                                  begin
                                                    puts "Running iteration #{purchase_multiple_refunds_task.name} : #{iteration}"
                                                    options = {:username => 'admin', :password => 'password'}
                                                    account = purchase_multiple_refunds_task.setup_account(options)

                                                    purchase = purchase_multiple_refunds_task.create_purchase(account.account_id, purchase_multiple_refunds_task.gen_key, purchase_multiple_refunds_task.gen_key, '20.40', account.currency, purchase_multiple_refunds_task.name, options)
                                                    purchase_multiple_refunds_task.create_refund(purchase.payment_id, purchase_multiple_refunds_task.gen_key, '10.20', account.currency, purchase_multiple_refunds_task.name, options)
                                                    purchase_multiple_refunds_task.create_refund(purchase.payment_id, purchase_multiple_refunds_task.gen_key, '10.20', account.currency, purchase_multiple_refunds_task.name, options)
                                                      #payments = purchase_multiple_refunds_task.get_payments_for_account(account.account_id, options)
                                                  rescue => e
                                                    puts "Task #{purchase_multiple_refunds_task.name} got an exception #{e.to_s}"
                                                  end
                                                end)
  load_pool.add_task(purchase_multiple_refunds_task, 5)

=begin
  auth_multi_capture_task = LoadTask.new(load_pool.pool,
                                         :AuthMultiCapture,
                                         Proc.new do |iteration|
                                           begin
                                             puts "Running iteration #{auth_multi_capture_task.name} : #{iteration}"
                                             options = {:username => 'admin', :password => 'password'}
                                             account = auth_multi_capture_task.setup_account(options)
                                             auth = auth_multi_capture_task.create_auth(account.account_id, auth_multi_capture_task.gen_key, auth_multi_capture_task.gen_key, '10.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.create_capture(auth.payment_id, auth_multi_capture_task.gen_key, '1.0', account.currency, auth_multi_capture_task.name, options)
                                             auth_multi_capture_task.create_void(auth.payment_id, auth_multi_capture_task.gen_key, auth_multi_capture_task.name, options)

                                               #payments = auth_multi_capture_task.get_payments_for_account(account.account_id, options)
                                           rescue => e
                                             puts "Task #{auth_multi_capture_task.name} got an exception #{e.to_s}"
                                           end
                                         end)
  load_pool.add_task(auth_multi_capture_task, 5)
=end

  credit_task = LoadTask.new(load_pool.pool,
                             :Credit,
                             Proc.new do |iteration|
                               begin
                                 puts "Running iteration #{credit_task.name} : #{iteration}"
                                 options = {:username => 'admin', :password => 'password'}
                                 account = credit_task.setup_account(options)
                                 credit = credit_task.create_credit(account.account_id, credit_task.gen_key, credit_task.gen_key, '34.76', account.currency, credit_task.name, options)
                                   #payments = credit_task.get_payments_for_account(account.account_id, options)
                               rescue => e
                                 puts "Task #{credit_task.name} got an exception #{e.to_s}"
                               end
                             end)
  load_pool.add_task(credit_task, 5)

  load_pool.run_tasks

end
