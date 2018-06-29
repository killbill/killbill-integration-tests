$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestInvoiceTemplate < Base

    def setup
      setup_base
      load_default_catalog
      @account = create_account(@user, @options)
    end

    def teardown
      teardown_base
    end

    def test_invoice_template
      internal_test_invoice_template(false)
    end

    def test_invoice_template_manual_pay
      internal_test_invoice_template(true)
    end

    def internal_test_invoice_template(manual_pay, locale = nil)
      # Upload a new template and verify it does indeed contain the magic string we added
      invoice_template = get_resource_as_string("HtmlInvoiceTemplate")
      result = KillBillClient::Model::Invoice.upload_invoice_template(invoice_template, manual_pay, false, @user, "Per tenant invoice template", "boo", @options)
      assert_true(result.include?("Tenant template"))

      got_exception = false
      begin
        KillBillClient::Model::Invoice.get_invoice_template(!manual_pay, locale, @options)
      rescue KillBillClient::API::NotFound => e
        got_exception = true
      end
      assert(got_exception, "Failed to get exception")


      got_exception = false
      begin
        KillBillClient::Model::Invoice.upload_invoice_template(invoice_template, manual_pay, false, @user, "Per tenant invoice template", "boo", @options)
      rescue KillBillClient::API::BadRequest => e
        got_exception = true
      end
      assert(got_exception, "Failed to get exception")

      invoice_template2 = get_resource_as_string("HtmlInvoiceTemplate2")
      result = KillBillClient::Model::Invoice.upload_invoice_template(invoice_template2, manual_pay, true, @user, "Per tenant invoice template", "boo", @options)
      assert_true(result.include?("Tenant (2) template"))

    end


    def test_invoice_translation

      # Upload new invoice translation and check for magic string
      invoice_translation = get_resource_as_string("InvoiceTranslation_fr_FR.properties")
      result = KillBillClient::Model::Invoice.upload_invoice_translation(invoice_translation, "fr_FR", false, @user, "Per tenant invoice translation", "boo", @options)
      assert_true(result.include?("Chauffeur"))
    end


    def test_catalog_translation

      # Upload new catalog translation and check for magic string
      catalog_translation = get_resource_as_string("CatalogTranslation_fr_FR.properties")
      result = KillBillClient::Model::Invoice.upload_catalog_translation(catalog_translation, "fr_FR", false, @user, "Per tenant catalog translation", "boo", @options)
      assert_true(result.include?("Voiture Sport"))
    end
  end

end
