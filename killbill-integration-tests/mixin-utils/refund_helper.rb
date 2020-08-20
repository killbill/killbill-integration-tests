# frozen_string_literal: true

module KillBillIntegrationTests
  module RefundHelper
    def refund(payment_id, amount, adjustments, user, options)
      item_adjustments = nil
      unless adjustments.nil?
        item_adjustments = []
        adjustments.each do |iia|
          item                 = KillBillClient::Model::InvoiceItem.new
          item.invoice_item_id = iia[:invoice_item_id]
          item.amount          = iia[:amount]
          item_adjustments << item
        end
      end

      KillBillClient::Model::InvoicePayment.refund(payment_id, amount, item_adjustments, user, nil, nil, options)
    end
  end
end
