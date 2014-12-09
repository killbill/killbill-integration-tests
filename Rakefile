#!/usr/bin/env rake

# Install tasks to build and release the plugin
require 'bundler/setup'
require 'rake'
require 'rake/testtask'

Bundler::GemHelper.install_tasks

BASE_DIR = 'killbill-integration-tests'

namespace :test do
  Rake::TestTask.new('entitlement') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/core/test_entitlement_*.rb",
                            "#{BASE_DIR}/core/test_pause_resume.rb",
                            "#{BASE_DIR}/core/test_transfer.rb",
                            "#{BASE_DIR}/core/test_usage.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('invoice') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/core/test_invoice_*.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('payment') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/core/test_payment.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('plugins:killbill-payment-test') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/plugins/killbill-payment-test/test_payment_with_control.rb",
                            "#{BASE_DIR}/plugins/killbill-payment-test/test_overdue.rb"]
    t.verbose    = true
  end

  Rake::TestTask.new('all') do |t|
    t.libs << BASE_DIR
    t.test_files = FileList["#{BASE_DIR}/core/test_*.rb"]
    t.verbose    = true
  end
end

# Run tests by default
task :default => 'test:all'
