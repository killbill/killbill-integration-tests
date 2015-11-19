require 'base'

LOGS_PREFIX = "#{LOGS_DIR}/account_#{START_TIME}"

scenario = test do
  header COMMON_HEADERS

  threads count: NB_THREADS.to_i, rampup: 30, duration: DURATION.to_i, on_sample_error: 'startnextloop' do

    counter = '${__counter(false)}'

    #
    # Create account
    #

    first, last = "John #{counter}", "Bill"
    account = {
        name: "#{first} #{last}",
        email: "johny#{counter}-#{START_TIME}@killbill.test",
        currency: 'USD'
    }
    post name: :'Create Account',
         url: KB_ACCOUNTS_URL,
         raw_body: account.to_json,
         headers: true do
      assert equals: 201, test_field: 'Assertion.response_code'
      extract name: 'account_id',
              regex: LOCATION_ID_REGEX,
              headers: true
    end
  end

  set_up_thread_group &DEFAULT_SETUP
  tear_down_thread_group &DEFAULT_TEARDOWN
end

run!(scenario, LOGS_PREFIX)
