module KillBillIntegrationTests
  module RefundHelper

    def refund(payment_id, amount, adjusted = false, adjustments = nil, user, options)
      refund = KillBillClient::Model::Refund.new
      refund.payment_id = payment_id
      refund.adjusted = adjusted
      refund.amount = amount
      if adjustments
        refund.adjustments = []
        adjustments.each do |iia|
          item = KillBillClient::Model::InvoiceItem.new
          item.invoice_item_id = iia[:invoice_item_id]
          item.currency = iia[:currency]
          item.amount = iia[:amount]
          refund.adjustments << item
        end
      end
      refund.create(user, nil, nil, options)

    end
  end
end