# frozen_string_literal: true

require 'base'

LOGS_PREFIX = "#{LOGS_DIR}/payment_combo_#{START_TIME}"

PLUGIN = ENV['PLUGIN'] || '__EXTERNAL_PAYMENT__'

# Usage example: NB_THREADS=10 DURATION=30 SKIP_GW=true PLUGIN=killbill-litle DEBUG=true ruby payment_combo.rb
scenario = test do
  header COMMON_HEADERS

  threads count: NB_THREADS.to_i, rampup: 30, duration: DURATION.to_i, on_sample_error: 'startnextloop' do
    counter = '${__counter(false)}'

    first = "John #{counter}"
    last = 'Bill'

    combo_transaction = {
      account: {
        name: "#{first} #{last}",
        externalKey: "johny#{counter}",
        email: "johny#{counter}-#{START_TIME}@killbill.io",
        currency: 'USD'
      },
      paymentMethod: {
        pluginName: PLUGIN,
        pluginInfo: {
          properties: [
            { key: 'email', value: 'tom@killbill.io' },
            { key: 'description', value: START_TIME },
            { key: 'ccFirstName', value: first },
            { key: 'ccLastName', value: last },
            { key: 'address1', value: '5th street' },
            { key: 'city', value: 'San Francisco' },
            { key: 'zip', value: '94111' },
            { key: 'state', value: 'CA' },
            { key: 'country', value: 'US' },
            { key: 'ccNumber', value: '4242424242424242' },
            { key: 'ccExpirationYear', value: '2020' },
            { key: 'ccExpirationMonth', value: '10' }
          ]
        }
      },
      paymentMethodPluginProperties: [
        { key: 'skip_gw', value: ENV['SKIP_GW'] == 'true' ? 'true' : 'false' }
      ],
      transaction: {
        transactionType: 'PURCHASE',
        amount: 10,
        currency: 'USD'
      },
      transactionPluginProperties: [
        { key: 'skip_gw', value: ENV['SKIP_GW'] == 'true' ? 'true' : 'false' }
      ]
    }

    post name: :'Purchase Payment (combo)',
         url: "#{KB_PAYMENTS_URL}/combo",
         raw_body: combo_transaction.to_json,
         headers: true do
      assert equals: 201, test_field: 'Assertion.response_code'
      extract name: 'payment_id',
              regex: LOCATION_ID_REGEX,
              headers: true
    end
  end

  set_up_thread_group(&DEFAULT_SETUP)
  tear_down_thread_group(&DEFAULT_TEARDOWN)
end

run!(scenario, LOGS_PREFIX)
