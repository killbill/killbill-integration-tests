module KillBillIntegrationTests
  module PaymentHelper

    def get_payments_for_account(account_id, options)

      account = KillBillClient::Model::Account.new
      account.account_id = account_id

      account.payments(options)
    end
  end
end