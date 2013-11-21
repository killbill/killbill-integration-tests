module KillBillIntegrationTests
  module InvoiceHelper


    def get_invoice_by_id(id, options)
      KillBillClient::Model::Invoice.find_by_id_or_number(id, true, "NONE", options)
    end

    def get_invoice_by_number(number, options)
      KillBillClient::Model::Invoice.find_by_id_or_number(number, true, "NONE", options)
    end

    def sort_invoices!(invoices)
      invoices.sort! do |a, b|
        a.invoice_date <=> b.invoice_date
      end
    end

  end
end
