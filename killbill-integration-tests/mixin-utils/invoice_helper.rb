module KillBillIntegrationTests
  module InvoiceHelper


    def get_invoice_by_id(id, options)
      KillBillClient::Model::Invoice.find_by_id_or_number(id, true, "NONE", options)
    end

    def get_invoice_by_number(number, options)
      KillBillClient::Model::Invoice.find_by_id_or_number(number, true, "NONE", options)
    end

    def create_charge(account_id, amount, currency, description, user, options)
      invoice_item  = KillBillClient::Model::InvoiceItem.new()
      invoice_item.account_id = account_id
      invoice_item.amount = amount
      invoice_item.currency = currency
      invoice_item.description = description
      invoice_item.create(user, nil, nil, options)
    end

    def sort_invoices!(invoices)
      invoices.sort! do |a, b|
        a.invoice_date <=> b.invoice_date
      end
    end

  end
end
