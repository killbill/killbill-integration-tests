module RubyJmeter
  class SaveResponsesToAFile
    def initialize(params={})
      options = params.is_a?(Hash) ? params : {}
      testname = params[:name] || 'SaveResponsesToAFile'
      @doc = Nokogiri::XML(<<-EOS.strip_heredoc)
<ResultSaver guiclass="ResultSaverGui" testclass="ResultSaver" testname="#{testname}" enabled="true">
  <stringProp name="FileSaver.filename">#{options[:filename]}</stringProp>
  <stringProp name="FileSaver.variablename">#{options[:variable]}</stringProp>
  <boolProp name="FileSaver.addTimstamp">#{!! options[:timestamp]}</boolProp>
  <boolProp name="FileSaver.successonly">#{!! options[:success_only]}</boolProp>
  <boolProp name="FileSaver.errorsonly">#{!! options[:errors_only]}</boolProp>
  <boolProp name="FileSaver.skipautonumber">#{! options.fetch(:auto_number) { true }}</boolProp>
  <boolProp name="FileSaver.skipsuffix">#{! options.fetch(:suffix) { true }}</boolProp>
</ResultSaver>)
      EOS
      update params
      update_at_xpath params if params.is_a?(Hash) && params[:update_at_xpath]
    end
  end
end
