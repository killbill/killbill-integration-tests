$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestPayment < Base

    def setup
      @user = "Payment"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account          = create_account(@user, default_time_zone, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, @user, @options)
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

      payment1_key      = 'payment1-' + Time.now.to_i.to_s
      payment1_currency = 'BTC'
      payment2_key      = 'payment2-' + Time.now.to_i.to_s
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
      void2     = create_void(auth2.payment_id, void2_key, {}, @user, @options)
      check_transaction(void2, payment2_key, void2_key, void, nil, nil, success)

      # Try to capture the second auth
      assert_raise 'Invalid transition' do
        create_capture(auth2.payment_id, Time.now.to_i.to_s, '12', payment2_currency, @user, @options)
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
                    auth2_amount,
                    0,
                    0,
                    0,
                    0,
                    [
                        [auth2_key, authorize, auth2_amount, payment2_currency, success], # auth 2
                        [void2_key, void, nil, nil, success] # void
                    ])
    end
  end
end