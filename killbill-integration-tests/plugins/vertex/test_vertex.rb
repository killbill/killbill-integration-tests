# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../..', __dir__)
$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'plugin_base'

module KillBillIntegrationTests
  class TestVertex < KillBillIntegrationTests::PluginBase
    PLUGIN_KEY = 'vertex'
    PLUGIN_NAME = 'killbill-vertex'
    # Default to latest
    PLUGIN_VERSION = nil

    PLUGIN_PROPS = [{ key: 'pluginArtifactId', value: 'vertex-plugin' },
                    { key: 'pluginGroupId', value: 'org.kill-bill.billing.plugin.java' },
                    { key: 'pluginType', value: 'java' }].freeze

    PLUGIN_CONFIGURATION = "org.killbill.billing.plugin.vertex.url=#{ENV['VERTEX_URL']}" + "\n" \
                           "org.killbill.billing.plugin.vertex.clientId=#{ENV['VERTEX_CLIENT_ID']}" + "\n" \
                           "org.killbill.billing.plugin.vertex.clientSecret=#{ENV['VERTEX_CLIENT_SECRET']}" + "\n" \
                           "org.killbill.billing.plugin.vertex.companyName=#{ENV['VERTEX_COMPANY_NAME']}" + "\n" \
                           "org.killbill.billing.plugin.vertex.companyDivision=#{ENV['VERTEX_COMPANY_DIVISION']}"

    KILLBILL_VERTEX_PREFIX = '/plugins/killbill-vertex'

    def setup
      @user = 'Vertex test plugin'
      setup_plugin_base('2020-05-01', PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
      set_configuration(PLUGIN_NAME, PLUGIN_CONFIGURATION)
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY)
    end

    def test_healthcheck
      healthcheck = if ENV['VERTEX_CLIENT_SECRET'].nil?
                      JSON.parse(KillBillClient::API.get("#{KILLBILL_VERTEX_PREFIX}/healthcheck", {}, {}).body)
                    else
                      # This will hit Vertex
                      JSON.parse(KillBillClient::API.get("#{KILLBILL_VERTEX_PREFIX}/healthcheck", {}, @options).body)
                    end
      assert_equal(1, healthcheck.size)

      if ENV['VERTEX_CLIENT_SECRET'].nil?
        assert_equal('Vertex OK (unauthenticated)', healthcheck['message'])
      else
        assert_equal('Vertex OK', healthcheck['message'])
      end
    end
  end
end
