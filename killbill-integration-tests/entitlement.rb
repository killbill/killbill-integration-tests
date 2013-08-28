$LOAD_PATH.unshift File.expand_path('..', __FILE__)
require 'test_helper'

class EntitlementTest < Test::Unit::TestCase

  KillBillClient.url = 'http://127.0.0.1:8080'


  def setup

    @user = "EntitlementTest"

    # RBAC default options
    @options = {:username => 'admin', :password => 'password'}

    # Create tenant and provide options for multi-tenants headers(X-Killbill-ApiKey/X-Killbill-ApiSecret)
    tenant = setup_create_tenant
    @options[:api_key] = tenant.api_key
    @options[:api_secret] = tenant.api_secret

    # Create account
    setup_create_account
  end

  def teardown
  end

  def setup_create_tenant
    tenant = KillBillClient::Model::Tenant.new
    tenant.external_key = Time.now.to_i.to_s
    tenant.api_key = 'test-api-key' + tenant.external_key
    secret_key = 'test-api-secret' + tenant.external_key
    tenant.api_secret = secret_key

    tenant = tenant.create(@user, nil, nil, @options)
    assert_not_nil(tenant)
    assert_not_nil(tenant.tenant_id)
    # Set the secret key again before returning as this is not returned by the server
    tenant.api_secret = secret_key
    tenant
  end

  def setup_create_account
    external_key = Time.now.to_i.to_s
    account = KillBillClient::Model::Account.new
    account.name = 'KillBillClient'
    account.external_key = external_key
    account.email = 'kill@bill.com'
    account.currency = 'USD'
    account.time_zone = 'UTC'
    account.address1 = '7, yoyo road'
    account.address2 = 'Apt 5'
    account.postal_code = 10293
    account.company = 'Unemployed'
    account.city = 'Foo'
    account.state = 'California'
    account.country = 'LalaLand'
    account.locale = 'FR_fr'
    account.is_notified_for_invoices = false
    assert_nil(account.account_id)
    account = account.create(@user, nil, nil, @options)
    assert_not_nil(account)
    assert_not_nil(account.account_id)
    @account = account
  end

  def test_entitlement

    # Create BP
    base_entitlement = KillBillClient::Model::EntitlementNoEvents.new
    base_entitlement.account_id = @account.account_id
    base_entitlement.external_key = Time.now.to_i.to_s
    base_entitlement.product_name = 'Sports'
    base_entitlement.product_category = 'BASE'
    base_entitlement.billing_period = 'MONTHLY'
    base_entitlement.price_list = 'DEFAULT'

    base_entitlement = base_entitlement.create(@user, nil, nil, @options)
    assert_not_nil(base_entitlement.subscription_id)
    assert_equal(base_entitlement.product_name, 'Sports')
    assert_equal(base_entitlement.product_category, 'BASE')
    assert_equal(base_entitlement.billing_period, 'MONTHLY')
    assert_equal(base_entitlement.price_list, 'DEFAULT')
    assert_nil(base_entitlement.cancelled_date)

    # Change plan
    base_entitlement = base_entitlement.change_plan({:productName => 'Super', :billingPeriod => 'MONTHLY', :priceList => 'DEFAULT'}, @user, nil, nil, nil, nil, false, @options)
    assert_equal(base_entitlement.product_name, 'Super')
    assert_equal(base_entitlement.product_category, 'BASE')
    assert_equal(base_entitlement.billing_period, 'MONTHLY')
    assert_equal(base_entitlement.price_list, 'DEFAULT')
    assert_nil(base_entitlement.cancelled_date)

    # Create Add-on
    ao_entitlement = KillBillClient::Model::EntitlementNoEvents.new
    ao_entitlement.bundle_id = base_entitlement.bundle_id
    ao_entitlement.product_name = 'RemoteControl'
    ao_entitlement.product_category = 'ADD_ON'
    ao_entitlement.billing_period = 'MONTHLY'
    ao_entitlement.price_list = 'DEFAULT'

    # Create ADD_ON
    ao_entitlement = ao_entitlement.create(@user, nil, nil, @options)
    assert_not_nil(ao_entitlement.subscription_id)
    assert_equal(ao_entitlement.product_name, 'RemoteControl')
    assert_equal(ao_entitlement.product_category, 'ADD_ON')
    assert_equal(ao_entitlement.billing_period, 'MONTHLY')
    assert_equal(ao_entitlement.price_list, 'DEFAULT')
    assert_nil(ao_entitlement.cancelled_date)

    # Cancel BP
    base_entitlement.cancel(@user, nil, nil, "2013-08-26T21:00:00.00Z", nil, @options)
  end
end
