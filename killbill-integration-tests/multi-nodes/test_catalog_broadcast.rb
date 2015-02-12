$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestCatalogBroadcast < Base

    def setup
      @user = "CatalogBroadcast"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
    end

    def teardown
      teardown_base
    end

    def test_multi_node

      catalog_file_xml = get_resource_as_string("Catalog-v1.xml")
      KillBillClient::Model::Catalog.upload_tenant_catalog(catalog_file_xml, @user, "Initial Catalog", "upload catalog for tenant", @options)

      catalog_file_xml_result_1 = KillBillClient::Model::Catalog.get_tenant_catalog(@options)

      wait_for_killbill(@options)

      reset_killbill_client_url(DEFAULT_KB_ADDRESS, '8081')

      catalog_file_xml_result_2 = KillBillClient::Model::Catalog.get_tenant_catalog(@options)

      assert_equal(catalog_file_xml_result_1, catalog_file_xml_result_2, "Failed to compare the per-tenant catalog from both nodes")
    end

  end
end
