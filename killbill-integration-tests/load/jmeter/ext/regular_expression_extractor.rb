# frozen_string_literal: true

module RubyJmeter
  class RegularExpressionExtractor
    def initialize(params = {})
      options = params.is_a?(Hash) ? params : {}
      testname = options[:name] || 'RegularExpressionExtractor'
      @doc = Nokogiri::XML(<<~EOS.strip_heredoc)
        <RegexExtractor guiclass="RegexExtractorGui" testclass="RegexExtractor" testname="#{testname}" enabled="true">
          <stringProp name="RegexExtractor.useHeaders">#{!!options[:headers]}</stringProp>
          <stringProp name="RegexExtractor.refname"/>
          <stringProp name="RegexExtractor.regex"/>
          <stringProp name="RegexExtractor.template"/>
          <stringProp name="RegexExtractor.default">#{options[:default]}</stringProp>
          <stringProp name="RegexExtractor.match_number">#{options[:match] || 1}</stringProp>
          #{'<stringProp name="Sample.scope">options[:scope]</stringProp>' if options[:scope]}
          #{'<stringProp name="Sample.scope">variable</stringProp>' if options[:variable]}
          #{'<stringProp name="Scope.variable">options[:variable]</stringProp>' if options[:variable]}
        </RegexExtractor>)
      EOS
      update params
      update_at_xpath params if params.is_a?(Hash) && params[:update_at_xpath]
    end
  end
end
