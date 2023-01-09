# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../..', __dir__)
$LOAD_PATH.unshift File.expand_path('..', __dir__)

require 'plugin_base'

module KillBillIntegrationTests
  class TestInvgrpDemo < KillBillIntegrationTests::PluginBase
    PLUGIN_KEY = 'invgrp'
    PLUGIN_NAME = 'invgrp-plugin'
    # Default to latest
    PLUGIN_VERSION = nil

    PLUGIN_PROPS = [{ key: 'pluginArtifactId', value: 'invgrp-plugin' },
                    { key: 'pluginGroupId', value: 'org.kill-bill.billing.plugin.java' },
                    { key: 'pluginType', value: 'java' }].freeze

    KILLBILL_INVGRP_PREFIX = '/plugins/invgrp-plugin'

    def setup
      @user = 'Invoice Group Demo plugin'
      setup_plugin_base('2020-05-01', PLUGIN_KEY, PLUGIN_VERSION, PLUGIN_PROPS)
      # set_configuration(PLUGIN_NAME, PLUGIN_CONFIGURATION)
    end

    def teardown
      teardown_plugin_base(PLUGIN_KEY)
    end

    def test_healthcheck
      healthcheck = JSON.parse(KillBillClient::API.get("#{KILLBILL_INVGRP_PREFIX}/healthcheck", {}, @options).body)
      assert_equal(1, healthcheck.size)
      assert_equal('Invgrp OK', healthcheck['message'])
    end
  end
end
