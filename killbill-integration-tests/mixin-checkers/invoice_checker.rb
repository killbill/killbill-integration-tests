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

    def check_usage_invoice_item_w_quantity(ii, invoice_id, amount, currency, item_type, plan_name, phase_name, usage_name, start_date, end_date, rate, quantity)
      msg = "invoice_item #{ii.invoice_item_id}"
      check_usage_invoice_item(ii, invoice_id, amount, currency, item_type, plan_name, phase_name, usage_name, start_date, end_date)
      assert_not_nil(ii.rate, msg)
      assert_not_nil(ii.quantity, msg)
      assert_equal(rate, ii.rate, msg)
      assert_equal(quantity, ii.quantity, msg)
    end

    
    def check_invoice_capacity_item_detail(ii, usage_input, amount)
      msg = "invoice_item #{ii.invoice_item_id}"
      assert_not_nil(ii.item_details, msg)
      details = JSON.parse(ii.item_details, :symbolize_names => true)
      detail_amount = details[:amount]
      item_details = details[:tierDetails]
      item_details.each_with_index do |item_detail, index|
        assert_equal(usage_input[index][:tier], item_detail[:tier], msg)
        assert_equal(usage_input[index][:unit_type], item_detail[:tierUnit], msg)
        assert_equal(usage_input[index][:unit_qty], item_detail[:quantity], msg)
        assert_equal(usage_input[index][:tier_price], item_detail[:tierPrice], msg)
      end
      assert_equal(amount, detail_amount, msg)
      assert_equal(usage_input.size, item_details.size)
    end

    def check_invoice_consumable_item_detail(ii, usage_input, amount)
      msg = "invoice_item #{ii.invoice_item_id}"
      assert_not_nil(ii.item_details, msg)
      details = JSON.parse(ii.item_details, :symbolize_names => true)
      detail_amount = details[:amount]
      item_details = details[:tierDetails]
      item_details.each_with_index do |item_detail, index|
        assert_equal(usage_input[index][:tier], item_detail[:tier], msg)
        assert_equal(usage_input[index][:unit_type], item_detail[:tierUnit], msg)
        assert_equal(usage_input[index][:unit_qty], item_detail[:quantity], msg)
        assert_equal(usage_input[index][:tier_price], item_detail[:tierPrice], msg)
      end
      assert_equal(amount, detail_amount, msg)
      assert_equal(usage_input.size, item_details.size)
    end

    def check_usage_invoice_item(ii, invoice_id, amount, currency, item_type, plan_name, phase_name, usage_name, start_date, end_date)
      msg = "invoice_item #{ii.invoice_item_id}"
      check_invoice_item(ii, invoice_id, amount, currency, item_type, plan_name, phase_name, start_date, end_date)
      assert_equal(usage_name, ii.usage_name, msg)
    end

  end
end
