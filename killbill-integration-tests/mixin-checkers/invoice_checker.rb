require 'checker_base'

module KillBillIntegrationTests
  module InvoiceChecker

    include CheckerBase

    def check_invoice_no_balance(i, amount, currency, invoice_date)
      assert_not_nil(i.invoice_number)
      assert_equal(amount, i.amount)
      assert_equal(currency, i.currency)
      assert_equal(invoice_date, i.invoice_date)
    end

    def check_invoice_item(ii, invoice_id, amount, currency, item_type, plan_name, phase_name, start_date, end_date)
      assert_equal(amount, ii.amount)
      assert_equal(invoice_id, ii.invoice_id)
      assert_equal(currency, ii.currency)
      assert_equal(item_type, ii.item_type)
      assert_equal(plan_name, ii.plan_name)
      assert_equal(phase_name, ii.phase_name)
      assert_equal(start_date, ii.start_date)
      assert_equal(end_date, ii.end_date)
    end

  end
end
