# frozen_string_literal: true

module RubyJmeter
  class DSL
    def post_thread_group(params = {}, &block)
      node = RubyJmeter::PostThreadGroup.new(params)
      attach_node(node, &block)
    end
    alias tear_down_thread_group post_thread_group
    def setup_thread_group(params = {}, &block)
      node = RubyJmeter::SetupThreadGroup.new(params)
      attach_node(node, &block)
    end
    alias set_up_thread_group setup_thread_group
  end

  class AroundThreadGroup
    attr_accessor :doc

    include Helper

    def initialize(params = {})
      options = params.is_a?(Hash) ? params : {}
      testname = options[:name] || 'tearDown Thread Group'
      testname = params.is_a?(Array) ? 'ThreadGroup' : (params[:name] || 'tearDown Thread Group')
      @doc = Nokogiri::XML(<<~EOS.strip_heredoc)
        <#{element_name} guiclass="#{gui_class}" testclass="#{test_class}" testname="#{testname}" enabled="true">
          <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
          <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlPanel" testclass="LoopController" testname="#{testname}" enabled="true">
            <boolProp name="LoopController.continue_forever">false</boolProp>
            <stringProp name="LoopController.loops">1</stringProp>
          </elementProp>
          <stringProp name="ThreadGroup.num_threads">1</stringProp>
          <stringProp name="ThreadGroup.ramp_time">1</stringProp>
          <longProp name="ThreadGroup.start_time">1366415241000</longProp>
          <longProp name="ThreadGroup.end_time">1366415241000</longProp>
          <boolProp name="ThreadGroup.scheduler">false</boolProp>
          <stringProp name="ThreadGroup.duration"/>
          <stringProp name="ThreadGroup.delay"/>
        </#{element_name}>)
      EOS
      update params
      update_at_xpath params if params.is_a?(Hash) && params[:update_at_xpath]
    end

    def element_name
      raise 'not implemented'
    end

    def test_class
      element_name
    end

    def gui_class
      "#{element_name}Gui"
    end
  end

  class PostThreadGroup < AroundThreadGroup
    def element_name
      'PostThreadGroup'
    end
  end

  class SetupThreadGroup < AroundThreadGroup
    def element_name
      'SetupThreadGroup'
    end
  end
end
