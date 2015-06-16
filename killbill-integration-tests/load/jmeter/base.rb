require 'rubygems'
require 'ruby-jmeter'
require 'base64'

require 'ext/regular_expression_extractor.rb'
require 'ext/save_responses_to_a_file.rb'
require 'ext/dsl.rb'

BASE_DIR = "#{File.expand_path(File.dirname(__FILE__))}"
LOGS_DIR = "#{BASE_DIR}/logs"

#
# Kill Bill configuration
#

KB_URL = ENV['KB_URL'] || 'http://127.0.0.1:8080'

KB_THREADS_URL = "#{KB_URL}/1.0/threads?pretty=true"
KB_METRICS_URL = "#{KB_URL}/1.0/metrics?pretty=true"

KB_ROOT = File.join(KB_URL, '/1.0/kb')
KB_ACCOUNTS_URL = "#{KB_ROOT}/accounts"

COMMON_HEADERS = [
  ENV['JSESSIONID'] ?
    { name: 'Cookie', value: "JSESSIONID=#{ENV['JSESSIONID']}" } :
    { name: 'Authorization', value: 'Basic ' + Base64.encode64("#{ENV['USERNAME'] || 'admin'}:#{ENV['PASSWORD'] || 'password'}").chomp },
  { name: 'X-Killbill-ApiKey',    value: ENV['API_KEY'] || 'bob' },
  { name: 'X-Killbill-ApiSecret', value: ENV['API_SECRET'] || 'lazar' },
  { name: 'X-Killbill-CreatedBy', value: ENV['CREATED_BY'] || 'JMeter' },
  { name: 'Accept', value: 'application/json' },
  { name: 'Content-Type', value: 'application/json' }
]

#
# JMeter configuration
#

NB_THREADS = ENV['NB_THREADS'] || 20
DURATION = ENV['DURATION'] || (5 * 60)

LOCATION_ID_REGEX = "Location: http://.*/(.+)/?"

DEFAULT_SETUP = Proc.new do
  save_responses_to_a_file filename: "#{LOGS_PREFIX}_setup_", timestamp: false

  get name: :'Threads', url: KB_THREADS_URL
  get name: :'Metrics', url: KB_METRICS_URL
end

DEFAULT_TEARDOWN = Proc.new do
  save_responses_to_a_file filename: "#{LOGS_PREFIX}_teardown_", timestamp: false

  get name: :'Threads', url: KB_THREADS_URL
  get name: :'Metrics', url: KB_METRICS_URL
end

START_TIME = Time.now.strftime('%Y-%m-%d-%H:%M')

def run!(scenario, logs_prefix="#{LOGS_DIR}/run_#{START_TIME}")
  if ENV['FLOOD_API_TOKEN']
    scenario.flood(
      ENV['FLOOD_API_TOKEN'],
      name: ENV['FLOOD_NAME'] || 'Load test',
      privacy_flag: ENV['FLOOD_PRIVACY_FLAG'] || 'private',
      grid: ENV['FLOOD_GRID']
    )
  else
    scenario.run(
        debug: ENV['DEBUG'] || false,
        properties: "#{BASE_DIR}/jmeter.properties",
        file: "#{logs_prefix}.jmx",
        log: "#{logs_prefix}.log",
        jtl: "#{logs_prefix}.jtl"
    )
  end
end