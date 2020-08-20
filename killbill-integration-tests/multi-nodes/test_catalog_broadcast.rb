# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'test_base'

module KillBillIntegrationTests
  class TestCatalogBroadcast < Base
    def setup
      @user = 'CatalogBroadcast'
      setup_base(@user)

      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    def test_multi_node
      catalog_file_xml = get_resource_as_string('Catalog-v1.xml')
      KillBillClient::Model::Catalog.upload_tenant_catalog(catalog_file_xml, @user, 'Initial Catalog', 'upload catalog for tenant', @options)

      catalog_file1_xml_result = KillBillClient::Model::Catalog.get_tenant_catalog(@options)

      wait_for_killbill(@options)

      reset_killbill_client_url(DEFAULT_KB_ADDRESS, '8081')

      catalog_file2_xml_result = KillBillClient::Model::Catalog.get_tenant_catalog(@options)

      assert_equal(catalog_file1_xml_result, catalog_file2_xml_result, 'Failed to compare the per-tenant catalog from both nodes')
    end
  end
end
