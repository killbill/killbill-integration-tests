$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'
require 'yaml'

module KillBillIntegrationTests

  class PluginBase < KillBillIntegrationTests::Base

    def setup_plugin_base(init_clock, plugin_key, plugin_version, plugin_props)
      setup_base(self.method_name, DEFAULT_MULTI_TENANT_INFO, init_clock)
      prepare_setup_sequence(plugin_key, plugin_version) do |seq|
        run_plugin_sequence("start", plugin_key, plugin_version, plugin_props, seq)
      end
    end

    def teardown_plugin_base(plugin_key)
      prepare_teardown_sequence(plugin_key) do |seq|
        run_plugin_sequence("stop", plugin_key, nil, [], seq)
      end
      teardown_base
    end

    def set_configuration(plugin_name, plugin_config)
      KillBillClient::Model::Tenant.upload_tenant_plugin_config(plugin_name,
                                                                plugin_config,
                                                                @user,
                                                                nil,
                                                                nil,
                                                                @options)
      # make sure to settle
      sleep 5
    end

    private

    def prepare_teardown_sequence(plugin_key)
      seq = %i[stop_plugin uninstall_plugin]

      plugin_state_file = plugin_key + '_temp_state.yml'
      if File.exist?(plugin_state_file)
        plugin_state = YAML.load_file(plugin_state_file)
        seq -= [:stop_plugin] unless plugin_state[:stop_plugin]
        seq -= [:uninstall_plugin] unless plugin_state[:uninstall_plugin]
      end

      yield seq unless seq.empty?
    end

    def prepare_setup_sequence(plugin_key, plugin_version)
      seq = %i[install_plugin start_plugin]
      plugins_info = get_plugin_information(plugin_key, plugin_version)

      is_installed = !(plugins_info.nil? || plugins_info.empty?)
      is_installed_and_running = is_installed && plugins_info.first.state == 'RUNNING'
      seq -= [:install_plugin] if is_installed

      # store stop sequence for the teardown, since it will run on every test
      plugin_state_file = plugin_key + '_temp_state.yml'
      File.delete(plugin_state_file) if File.exist?(plugin_state_file)
      File.new(plugin_state_file, 'w+')

      plugin_state = YAML.load_file(plugin_state_file) || {}
      plugin_state[:stop_plugin] = !is_installed_and_running
      plugin_state[:uninstall_plugin] = !is_installed

      File.open(plugin_state_file, 'r+') do |f|
        f.write(plugin_state.to_yaml)
      end

      puts "\e[36m#{plugin_key} is already installed\e[0m" if is_installed && !is_installed_and_running
      puts "\e[36m#{plugin_key} is already installed and running\e[0m" if is_installed_and_running
      return plugins_info.first if is_installed_and_running
      yield seq

      plugins_info = get_plugin_information(plugin_key, plugin_version) unless is_installed
      plugins_info.first
    end

    def get_plugin_information(plugin_key, plugin_version)
      nodes_info = KillBillClient::Model::NodesInfo.nodes_info(@options)
      return [] if nodes_info.nil?
      latest_version = Gem::Version.new('0.0.0')
      has_running_plugin = false

      plugins_info = nodes_info.first.plugins_info || []
      plugins_info.select! do |plugin|
        found = true
        found &= plugin.plugin_key.include?(plugin_key) unless plugin.plugin_key.nil?
        found |= plugin.plugin_name.include?(plugin_key)
        found &= (plugin_version.nil? || plugin_version.empty? || plugin.version == plugin_version)

        if found
          version = Gem::Version.new(plugin.version)
          latest_version = version if version > latest_version
          has_running_plugin |= plugin.state == 'RUNNING'
        end

        found
      end
      # if there are multiple versions find the running one or the latest
      unless plugins_info.nil?
        plugins_info.select! { |plugin| plugin.state == 'RUNNING' } if has_running_plugin
        plugins_info.select! { |plugin| plugin.version == latest_version.to_s } unless has_running_plugin
      end

      plugins_info
    end

    def run_plugin_sequence(seq_name, plugin_key, plugin_version, plugin_props, seq)
      begin
        seq.each do |cmd|
          puts "Running #{cmd} for #{plugin_key}..."
          plugin_info = KillBillClient::Model::NodesInfo.send(cmd, plugin_key, plugin_version, plugin_props, true, @user, nil, nil, @options, 30)
          puts "-> #{cmd} for #{plugin_key} completed (#{plugin_info.inspect})"
        end
      rescue Timeout::Error
        flunk "Failed to run #{seq_name} sequence for #{plugin_key}"
      end
      # make sure to settle
      sleep 5
    end

  end
end