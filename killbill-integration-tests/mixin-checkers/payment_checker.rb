require 'checker_base'

module KillBillIntegrationTests
  module PaymentChecker

    include CheckerBase

    def check_payment(p, account_id, payment_external_key, auth_amount, captured_amount, purchased_amount, refunded_amount, credited_amount, transactions)
      assert_equal(account_id, p.account_id)
      assert_equal(payment_external_key, p.payment_external_key)
      assert_equal(auth_amount.to_f, p.auth_amount)
      assert_equal(captured_amount.to_f, p.captured_amount)
      assert_equal(purchased_amount.to_f, p.purchased_amount)
      assert_equal(refunded_amount.to_f, p.refunded_amount)
      assert_equal(credited_amount.to_f, p.credited_amount)
      assert_not_nil(p.payment_id)
      assert_not_nil(p.payment_number)
      assert_not_nil(p.payment_method_id)
      assert_equal(transactions.size, p.transactions.size)
      # transactions is of the form
      # [
      #   [transaction_external_key, transaction_type, amount, currency, status]
      # ]
      p.transactions.each_with_index do |t, i|
        check_transaction(t, payment_external_key, transactions[i][0], transactions[i][1], transactions[i][2], transactions[i][3], transactions[i][4])
      end
    end

    def check_transaction(t, payment_external_key, transaction_external_key, transaction_type, amount, currency, status)
      assert_equal(payment_external_key, t.payment_external_key)
      assert_equal(transaction_external_key, t.transaction_external_key)
      assert_equal(transaction_type, t.transaction_type)
      assert_equal(transaction_type, t.transaction_type)
      amount.nil? ? assert_nil(t.amount) : assert_equal(amount.to_f, t.amount)
      assert_equal(currency, t.currency)
      assert_equal(status, t.status)
      assert_not_nil(t.payment_id)
      assert_not_nil(t.transaction_id)
      assert_not_nil(t.effective_date)
    end
  end
end
