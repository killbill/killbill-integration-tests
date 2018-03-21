$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestPayment < Base

    def setup
      setup_base
      load_default_catalog

      @account          = create_account(@user, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)
    end

    def teardown
      teardown_base
    end

    def test_multiple_auth_captures
      authorize = 'AUTHORIZE'
      capture   = 'CAPTURE'
      refund    = 'REFUND'
      void      = 'VOID'
      success   = 'SUCCESS'

      payment1_key      = 'payment1-' + rand(1000000).to_s
      payment1_currency = 'BTC'
      payment2_key      = 'payment2-' + rand(1000000).to_s
      payment2_currency = 'USD'

      # Auth the first payment
      auth1_key         = payment1_key + '-auth1'
      auth1_amount      = '240922.1504832'
      auth1             = create_auth(@account.account_id, payment1_key, auth1_key, auth1_amount, payment1_currency, @user, @options)
      check_transaction(auth1, payment1_key, auth1_key, authorize, auth1_amount, payment1_currency, success)

      # Auth the second payment
      auth2_key    = payment2_key + '-auth1'
      auth2_amount = '23.23'
      auth2        = create_auth(@account.account_id, payment2_key, auth2_key, auth2_amount, payment2_currency, @user, @options)
      check_transaction(auth2, payment2_key, auth2_key, authorize, auth2_amount, payment2_currency, success)

      # Partially capture the first auth
      capture11_key    = payment1_key + '-capture1'
      capture11_amount = '483.22'
      capture11        = create_capture(auth1.payment_id, capture11_key, capture11_amount, payment1_currency, @user, @options)
      check_transaction(capture11, payment1_key, capture11_key, capture, capture11_amount, payment1_currency, success)

      # Void the second auth
      void2_key = payment2_key + '-void'
      void2     = create_void(auth2.payment_id, void2_key, @user, @options)
      check_transaction(void2, payment2_key, void2_key, void, nil, nil, success)

      # Try to capture the second auth
      assert_raise 'Invalid transition' do
        create_capture(auth2.payment_id, rand(1000000).to_s, '12', payment2_currency, @user, @options)
      end

      # Partially capture the first auth
      capture12_key    = payment1_key + '-capture2'
      capture12_amount = '293.0002'
      capture12        = create_capture(auth1.payment_id, capture12_key, capture12_amount, payment1_currency, @user, @options)
      check_transaction(capture12, payment1_key, capture12_key, capture, capture12_amount, payment1_currency, success)

      # Partially refund the first capture
      refund11_key    = payment1_key + '-refund1'
      refund11_amount = '100'
      refund11        = create_refund(auth1.payment_id, refund11_key, refund11_amount, payment1_currency, @user, @options)
      check_transaction(refund11, payment1_key, refund11_key, refund, refund11_amount, payment1_currency, success)

      # Partially refund the second capture
      refund12_key    = payment1_key + '-refund2'
      refund12_amount = '1.23'
      refund12        = create_refund(auth1.payment_id, refund12_key, refund12_amount, payment1_currency, @user, @options)
      check_transaction(refund12, payment1_key, refund12_key, refund, refund12_amount, payment1_currency, success)

      # Verify the account balance and CBA
      account = get_account(@account.account_id, true, true, @options)
      assert_equal(0.0, account.account_balance)
      assert_equal(0.0, account.account_cba)

      # Verify the account payments
      payments = get_payments_for_account(@account.account_id, @options)
      assert_equal(2, payments.size)
      check_payment(payments[0],
                    @account.account_id,
                    payment1_key,
                    auth1_amount,
                    capture11_amount.to_f + capture12_amount.to_f,
                    0,
                    refund11_amount.to_f + refund12_amount.to_f,
                    0,
                    [
                        [auth1_key, authorize, auth1_amount, payment1_currency, success], # auth 1
                        [capture11_key, capture, capture11_amount, payment1_currency, success], # capture 1
                        [capture12_key, capture, capture12_amount, payment1_currency, success], # capture 2
                        [refund11_key, refund, refund11_amount, payment1_currency, success], # refund 1
                        [refund12_key, refund, refund12_amount, payment1_currency, success] # refund 2
                    ])
      check_payment(payments[1],
                    @account.account_id,
                    payment2_key,
                    0,
                    0,
                    0,
                    0,
                    0,
                    [
                        [auth2_key, authorize, auth2_amount, payment2_currency, success], # auth 2
                        [void2_key, void, nil, nil, success] # void
                    ])
    end

    def test_create_chargeback_and_chargeback_reversal

      account = create_account(@user, @options)
      account = get_account(account.account_id, true, true, @options)

      # Create a charge to account
      create_charge(account.account_id, '50.0', 'USD', 'My charge', @user, @options)
      # Create a payment
      pay_all_unpaid_invoices(account.account_id, true, '50.0', @user, @options)
      account = get_account(account.account_id, true, true, @options)
      payment = account.payments(@options).first
      # Verify if a new transaction is created and if their type is PURCHASE
      account_transactions = account.payments(@options).first.transactions
      assert_equal(1, account_transactions.size)
      assert_equal('PURCHASE', account_transactions[0].transaction_type)
      assert_equal(0, get_account(account.account_id, true, true, @options).account_balance)

      # Trigger chargeback
      transaction                          = KillBillClient::Model::Transaction.new
      transaction.payment_id               = payment.payment_id
      transaction.payment_external_key     = 'test_key'
      transaction.amount                   = '50.0'
      transaction.currency                 = 'USD'
      transaction.effective_date           = nil
      transaction.chargeback_by_external_key(@user, nil, nil, @options, nil)

      # Verify if a new transaction is created and if their type is CHARGEBACK
      account_transactions = account.payments(@options).first.transactions
      assert_equal(2, account_transactions.size)
      assert_equal('CHARGEBACK', account_transactions[1].transaction_type)
      assert_equal('SUCCESS', account_transactions[1].status)

      # Trigger chargeback reversal
      transaction                          = KillBillClient::Model::Transaction.new
      transaction.transaction_external_key = account_transactions[1].transaction_external_key
      transaction.payment_id               = account_transactions[1].payment_id
      transaction.chargeback_reversals(@user, nil, nil, @options)

      # Verify if a new transaction is created and if their type is CHARGEBACK
      account_transactions = account.payments(@options).first.transactions
      assert_equal(3, account_transactions.size)
      assert_equal('CHARGEBACK', account_transactions[2].transaction_type)
      assert_equal(0, get_account(account.account_id, true, true, @options).account_balance)
      assert_equal('PAYMENT_FAILURE', account_transactions[2].status)

    end

    def test_payment_refund_by_external_key

      account = create_account(@user, @options)
      account = get_account(account.account_id, true, true, @options)

      # Create a charge to account
      create_charge(account.account_id, '50.0', 'USD', 'My charge', @user, @options)

      # Create a payment
      pay_all_unpaid_invoices(account.account_id, true, '50.0', @user, @options)
      account = get_account(account.account_id, true, true, @options)
      payment = account.payments(@options).first


      # Verify if a new transaction is created and if their type is PURCHASE
      account_transactions = account.payments(@options).first.transactions
      assert_equal(1, account_transactions.size)
      assert_equal('PURCHASE', account_transactions[0].transaction_type)
      assert_equal(0, get_account(account.account_id, true, true, @options).account_balance)

      # Verify if refunded amount is 0
      assert_equal(0, payment.refunded_amount)


      # Refund 50 payment
      transaction                          = KillBillClient::Model::Transaction.new
      transaction.payment_external_key     = payment.payment_external_key
      transaction.amount                   = '50.0'
      transaction.refund_by_external_key(@user, nil, nil, @options, nil)

      payment = KillBillClient::Model::Payment.find_by_id(payment.payment_id, false, false, @options)

      # Verify if refunded amount is 50
      assert_equal(50, payment.refunded_amount)

    end
  end
end
