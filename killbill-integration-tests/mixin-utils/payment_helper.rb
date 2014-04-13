module KillBillIntegrationTests
  module PaymentHelper

    def get_payments_for_account(account_id, options)

      account = KillBillClient::Model::Account.new
      account.account_id = account_id
      account.payments(options)
    end

    def pay_all_unpaid_invoices(account_id, external_payment, payment_amount, user, options)
      payment = KillBillClient::Model::Payment.new
      payment.account_id = account_id
      payment.create(external_payment, payment_amount, user, nil, nil, options)
    end
  end
end