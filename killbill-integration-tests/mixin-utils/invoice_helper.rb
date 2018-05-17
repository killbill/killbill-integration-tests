module KillBillIntegrationTests
  module InvoiceHelper

    def check_next_invoice_amount(invoice_nb, amount, invoice_date, account, options, &proc_account_invoices_nb)
      wait_for_expected_clause(invoice_nb, account, options, &proc_account_invoices_nb)

      all_invoices = account.invoices(true, options)
      assert_equal(invoice_nb, all_invoices.size, "Invalid number of invoices: #{all_invoices.size}")

      sort_invoices!(all_invoices)
      sort_invoice_items!(all_invoices)

      new_invoice = all_invoices[invoice_nb - 1]
      check_invoice_no_balance(new_invoice, amount, 'USD', invoice_date)

      all_invoices
    end

    def get_invoice_payment(payment_id, options)
      KillBillClient::Model::InvoicePayment.find_by_id(payment_id, false, false, options)
    end

    def get_invoice_by_id(id, options)
      KillBillClient::Model::Invoice.find_by_id(id, true, "NONE", options)
    end

    def get_invoice_by_number(number, options)
      KillBillClient::Model::Invoice.find_by_number(number, true, "NONE", options)
    end

    def create_charge(account_id, amount, currency, description, user, options)
      invoice_item             = KillBillClient::Model::InvoiceItem.new()
      invoice_item.account_id  = account_id
      invoice_item.amount      = amount
      invoice_item.currency    = currency
      invoice_item.description = description
      invoice_item.create(true, user, nil, nil, options)
    end


    def create_account_credit(account_id, amount, currency, description, user, options)
      credit_item                 = KillBillClient::Model::Credit.new()
      credit_item.account_id      = account_id
      credit_item.credit_amount   = amount
      credit_item.currency        = currency
      credit_item.description     = description
      credit_item.create(true, user, nil, nil, options)
    end

    def adjust_invoice_item(account_id, invoice_id, invoice_item_id, amount, currency, description, user, options)
      invoice_item                 = KillBillClient::Model::InvoiceItem.new()
      invoice_item.account_id      = account_id
      invoice_item.invoice_id      = invoice_id
      invoice_item.invoice_item_id = invoice_item_id
      invoice_item.amount          = amount
      invoice_item.currency        = currency
      invoice_item.description     = description
      invoice_item.update(user, nil, nil, options)
    end


    def trigger_invoice_dry_run(account_id, target_date, upcoming_invoice_target_date, options = {})
      KillBillClient::Model::Invoice.trigger_invoice_dry_run(account_id, target_date, upcoming_invoice_target_date, options);
    end

    def create_subscription_dry_run(account_id, bundle_id, target_date, product_name, product_category, billing_period,
                                    price_list_name, options = {})
      KillBillClient::Model::Invoice.create_subscription_dry_run(account_id, bundle_id, target_date, product_name, product_category,
                                                                 billing_period, price_list_name, options)
    end


    def change_plan_dry_run(account_id, bundle_id, subscription_id, target_date, product_name, product_category, billing_period, price_list_name,
                            effective_date, billing_policy, options = {})
      KillBillClient::Model::Invoice.change_plan_dry_run(account_id, bundle_id, subscription_id, target_date, product_name, product_category, billing_period, price_list_name,
                                                         effective_date, billing_policy, options)
    end

    def cancel_subscription_dry_run(account_id, bundle_id, subscription_id, target_date,
                                    effective_date, billing_policy, options = {})
      KillBillClient::Model::Invoice.cancel_subscription_dry_run(account_id, bundle_id, subscription_id, target_date,
                                                                 effective_date, billing_policy, options)
    end

    def sort_invoices!(invoices)
      invoices.sort! do |a, b|
        a.invoice_date == b.invoice_date ? a.invoice_number <=> b.invoice_number : a.invoice_date <=> b.invoice_date
      end
    end

    def sort_invoice_items!(all_invoices)
      all_invoices.each do |invoice|
        invoice.items.sort! do |a, b|
          a.amount <=> b.amount
        end
      end
    end

    def get_specific_invoice_item(items, type, extra_condition)
      items.each do |i|
        if type == 'RECURRING' && i.phase_name == extra_condition && i.item_type == type
          return i
        elsif type == 'REPAIR_ADJ' && i.amount == extra_condition && i.item_type == type
          return i
        elsif type == 'CBA_ADJ' && i.amount == extra_condition && i.item_type == type
          return i
        elsif type == 'USAGE' && i.amount == extra_condition && i.item_type == type
          return i
        end
      end
      assert_not_nil(nil, "Could not find item for type #{type} , condition = #{extra_condition}")
    end
  end
end
