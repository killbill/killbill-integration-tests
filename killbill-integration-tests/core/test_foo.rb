$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestEntitlementAddOn < Base

    def setup
      @user = "EntitlementAddOn"
      setup_base(@user)


      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)
    end

    def teardown
      teardown_base
    end


  end
end

