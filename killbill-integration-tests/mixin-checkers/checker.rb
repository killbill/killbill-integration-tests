# frozen_string_literal: true

require 'entitlement_checker'
require 'invoice_checker'
require 'payment_checker'

module KillBillIntegrationTests
  module Checker
    include EntitlementChecker
    include InvoiceChecker
    include PaymentChecker
  end
end
