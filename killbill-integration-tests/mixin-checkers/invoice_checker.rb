require 'checker_base'

module KillBillIntegrationTests
  module InvoiceChecker

    include CheckerBase

    def check_invoice_no_balance(i, amount, currency, invoice_date)
      msg = "invoice #{i.invoice_id}"

      assert_not_nil(i.invoice_number)
      assert_equal(amount, i.amount,  msg)
      assert_equal(currency, i.currency, msg)
      assert_equal(invoice_date, i.invoice_date, msg)
    end

    def check_invoice_item(ii, invoice_id, amount, currency, item_type, plan_name, phase_name, start_date, end_date)
      msg = "invoice_item #{ii.invoice_item_id}"
      assert_equal(amount, ii.amount, msg)
      assert_equal(invoice_id, ii.invoice_id, msg)
      assert_equal(currency, ii.currency, msg)
      assert_equal(item_type, ii.item_type, msg)
      assert_equal(plan_name, ii.plan_name, msg)
      assert_equal(phase_name, ii.phase_name, msg)
      assert_equal(start_date, ii.start_date, msg)
      assert_equal(end_date, ii.end_date, msg)
    end

  end
end
