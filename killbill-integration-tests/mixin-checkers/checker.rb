
require 'entitlement_checker'
require 'invoice_checker'

module KillBillIntegrationTests
  module Checker

    include EntitlementChecker
    include InvoiceChecker

  end
end
