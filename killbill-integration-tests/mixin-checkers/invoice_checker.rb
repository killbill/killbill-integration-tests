require 'checker_base'

module KillBillIntegrationTests
  module InvoiceChecker

    include CheckerBase

    def check_invoice_no_balance(i, amount, currency, invoice_date)
      assert_not_nil(i.invoice_number)
      assert_equal(i.amount, amount)
      assert_equal(i.currency, currency)
      assert_equal(i.invoice_date, invoice_date)
    end

    def check_invoice_item(ii, invoice_id, amount, currency, item_type, plan_name, phase_name, start_date, end_date)
      assert_equal(ii.amount, amount)
      assert_equal(ii.invoice_id, invoice_id)
      assert_equal(ii.currency, currency)
      assert_equal(ii.item_type, item_type)
      assert_equal(ii.plan_name, plan_name)
      assert_equal(ii.phase_name, phase_name)
      assert_equal(ii.start_date, start_date)
      assert_equal(ii.end_date, end_date)
    end

  end
end
