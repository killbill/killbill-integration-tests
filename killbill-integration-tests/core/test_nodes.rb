$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'
require 'pp'

module KillBillIntegrationTests

  class TestNodes < Base

    def setup
      setup_base
    end

    def teardown
      teardown_base
    end

    # Test does not test anything per say but verify client api is correctly implemented
    def test_basic
      info = KillBillClient::Model::NodesInfo.nodes_info(@options)

      puts "info.to_json"

      node_command = KillBillClient::Model::NodeCommandAttributes.new
      node_command.system_command_type = true
      node_command.node_command_type = :START_PLUGIN
      node_command.node_command_properties = [{:key => 'pluginName', :value => 'FOO'}, {:key => 'pluginVersion', :value => '1.2.3'}]

      KillBillClient::Model::NodesInfo.trigger_node_command(node_command, false, @user, nil, nil, @options)
    end

  end
end
