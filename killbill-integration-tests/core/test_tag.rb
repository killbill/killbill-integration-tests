# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'test_base'
require 'pp'

module KillBillIntegrationTests
  class TestTag < Base
    def setup
      setup_base
      load_default_catalog

      @account = create_account(@user, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, nil, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)
    end

    def teardown
      teardown_base
    end

    def test_auto_pay_off
      @account.set_auto_pay_off(@user, nil, nil, @options)
      assert_true @account.auto_pay_off?(@options)
      @account.remove_auto_pay_off(@user, nil, nil, @options)
      assert_false @account.auto_pay_off?(@options)
    end

    def test_set_tags
      @account.add_tag('TEST', @user, nil, nil, @options)
      assert_true @account.control_tag?(KillBillClient::Model::TagHelper::TEST_ID, @options)
      assert_false @account.control_tag?(KillBillClient::Model::TagHelper::AUTO_PAY_OFF_ID, @options)
      assert_false @account.control_tag?(KillBillClient::Model::TagHelper::AUTO_INVOICING_OFF_ID, @options)
      @account.set_tags([
                          KillBillClient::Model::TagHelper::AUTO_PAY_OFF_ID,
                          KillBillClient::Model::TagHelper::AUTO_INVOICING_OFF_ID
                        ], @user, nil, nil, @options)
      assert_false @account.test?(@options)
      assert_true @account.auto_pay_off?(@options)
      assert_true @account.auto_invoicing_off?(@options)
    end
  end
end
