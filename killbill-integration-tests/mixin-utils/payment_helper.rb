module KillBillIntegrationTests
  module PaymentHelper

    def get_payments_for_account(account_id, options)
      account            = KillBillClient::Model::Account.new
      account.account_id = account_id
      account.payments(options)
    end

    def pay_all_unpaid_invoices(account_id, external_payment, payment_amount, user, options)
      payment                  = KillBillClient::Model::InvoicePayment.new
      payment.account_id       = account_id
      payment.purchased_amount = payment_amount
      payment.bulk_create(external_payment, nil, nil, user, nil, nil, options)
    end

    def create_auth(account_id, payment_external_key, transaction_external_key, amount, currency, user, options)
      transaction                          = KillBillClient::Model::Transaction.new
      transaction.amount                   = amount
      transaction.currency                 = currency
      transaction.payment_external_key     = payment_external_key
      transaction.transaction_external_key = transaction_external_key
      refreshed_transaction(transaction.auth(account_id, nil, user, nil, nil, options), transaction_external_key)
    end

    def create_purchase(account_id, payment_external_key, transaction_external_key, amount, currency, user, options)
      transaction                          = KillBillClient::Model::Transaction.new
      transaction.amount                   = amount
      transaction.currency                 = currency
      transaction.payment_external_key     = payment_external_key
      transaction.transaction_external_key = transaction_external_key
      refreshed_transaction(transaction.purchase(account_id, nil, user, nil, nil, options), transaction_external_key)
    end

    def create_credit(account_id, payment_external_key, transaction_external_key, amount, currency, user, options)
      transaction                          = KillBillClient::Model::Transaction.new
      transaction.amount                   = amount
      transaction.currency                 = currency
      transaction.payment_external_key     = payment_external_key
      transaction.transaction_external_key = transaction_external_key
      refreshed_transaction(transaction.credit(account_id, nil, user, nil, nil, options), transaction_external_key)
    end

    def create_capture(payment_id, transaction_external_key, amount, currency, user, options)
      transaction                          = KillBillClient::Model::Transaction.new
      transaction.payment_id               = payment_id
      transaction.amount                   = amount
      transaction.currency                 = currency
      transaction.transaction_external_key = transaction_external_key
      refreshed_transaction(transaction.capture(user, nil, nil, options), transaction_external_key)
    end

    def create_refund(payment_id, transaction_external_key, amount, currency, user, options)
      transaction                          = KillBillClient::Model::Transaction.new
      transaction.payment_id               = payment_id
      transaction.amount                   = amount
      transaction.currency                 = currency
      transaction.transaction_external_key = transaction_external_key
      refreshed_transaction(transaction.refund(user, nil, nil, options), transaction_external_key)
    end

    def create_void(payment_id, transaction_external_key, user, options)
      transaction                          = KillBillClient::Model::Transaction.new
      transaction.payment_id               = payment_id
      transaction.transaction_external_key = transaction_external_key
      refreshed_transaction(transaction.void(user, nil, nil, options), transaction_external_key)
    end

    def refreshed_transaction(payment, transaction_external_key)
      # There is no refresh in case of plugin timeout for instance
      payment.is_a?(KillBillClient::Model::Transaction) ? payment : payment.transactions.find { |t| t.transaction_external_key == transaction_external_key.to_s }
    end
  end
end
