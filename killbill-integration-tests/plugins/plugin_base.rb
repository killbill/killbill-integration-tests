$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class PluginBase < KillBillIntegrationTests::Base

    def setup_plugin_base(init_clock, plugin_key, plugin_version, plugin_props)
      setup_base(self.method_name, DEFAULT_MULTI_TENANT_INFO, init_clock)

      run_plugin_sequence("start", plugin_key, plugin_version, plugin_props, [:install_plugin, :start_plugin])
    end


    def teardown_plugin_base(plugin_key)
      run_plugin_sequence("stop", plugin_key, nil, [], [:stop_plugin, :uninstall_plugin])
      teardown_base
    end


    private

    def run_plugin_sequence(seq_name, plugin_key, plugin_version, plugin_props, seq)
      begin
        seq.each do |cmd|
          puts "Running #{cmd} for #{plugin_key}..."
          plugin_info = KillBillClient::Model::NodesInfo.send(cmd, plugin_key, plugin_version, plugin_props, true, @user, nil, nil, @options)
          puts "-> #{cmd} for #{plugin_key} completed (#{plugin_info.inspect})"
        end
      rescue Timeout::Error
        flunk "Failed to run #{seq_name} sequence for #{plugin_key}"
      end
    end

  end
end