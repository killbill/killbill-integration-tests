#!/usr/bin/env rake

# Install tasks to build and release the plugin
require 'bundler/setup'
require 'rake'
require 'rake/testtask'

Bundler::GemHelper.install_tasks

BASE_DIR = 'killbill-integration-tests'

namespace :test do
  Rake::TestTask.new('core:entitlement') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/core/test_entitlement_*.rb",
                            "#{BASE_DIR}/core/test_pause_resume.rb",
                            "#{BASE_DIR}/core/test_transfer.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('core:usage') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/core/usage/test_*.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('core:invoice') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/core/test_invoice_*.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('core:payment') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/core/test_payment.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('core:tag') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/core/test_tag.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('plugins:killbill-payment-test') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/plugins/killbill-payment-test/test_*.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('plugins:avatax') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/plugins/avatax/test_*.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('plugins:killbill-email-notifications') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/plugins/killbill-email-notifications/test_*.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('plugins') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/plugins/*/test_*.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('multi-nodes') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/multi-nodes/test_*.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('core') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/core/test_*.rb",
                            "#{BASE_DIR}/core/usage/test_*.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('all') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/core/test_*.rb",
                            "#{BASE_DIR}/plugins/*/test_*.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('seed') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/seed/seed_account_timezone.rb",
                            "#{BASE_DIR}/seed/seed_billing_alignment.rb",
                            "#{BASE_DIR}/seed/seed_refund.rb",
                            "#{BASE_DIR}/seed/seed_subscription_alignment.rb",
                            "#{BASE_DIR}/seed/seed_subscription_cancellation.rb",
                            "#{BASE_DIR}/seed/seed_subscription_with_usage.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('seed:kaui') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/seed/seed_kaui.rb"]
    t.verbose    = true
  end
end

namespace :ci do
  require 'ci/reporter/rake/test_unit'
  task :core => ['ci:setup:testunit', 'test:core']
  task :all => ['ci:setup:testunit', 'test:all']
end

# Run tests by default
task :default => 'test:all'
