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

    def trigger_invoice_dry_run(account_id, target_date, options = {})
      KillBillClient::Model::Invoice.trigger_invoice_dry_run(account_id, target_date, options);
    end

    def create_subscription_dry_run(account_id, bundle_id, target_date, product_name, product_category, billing_period,
        price_list_name,  options = {})
      KillBillClient::Model::Invoice.create_subscription_dry_run(account_id, bundle_id, target_date, product_name, product_category,
                                                                 billing_period, price_list_name, options)
    end


    def change_plan_dry_run(account_id, bundle_id, subscription_id, target_date, product_name, product_category, billing_period, price_list_name,
        effective_date, billing_policy, options = {})
      KillBillClient::Model::Invoice.change_plan_dry_run(account_id, bundle_id, subscription_id, target_date, product_name, product_category, billing_period, price_list_name,
                                                         effective_date, billing_policy, options)
    end

    def cancel_subscription_dry_run(account_id, bundle_id, subscription_id, target_date,
        effective_date, billing_policy,  options = {})
      KillBillClient::Model::Invoice.cancel_subscription_dry_run(account_id, bundle_id, subscription_id, target_date,
                                                                 effective_date, billing_policy, options)
    end


    def sort_invoices!(invoices)
      invoices.sort! do |a, b|
        a.invoice_date <=> b.invoice_date
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
      assert_not_nil(nil, "Counf not find item for type #{type} , condition = #{extra_condition}")
    end

  end
end
