require 'base'

LOGS_PREFIX = "#{LOGS_DIR}/payment_#{START_TIME}"

PLUGIN = ENV['PLUGIN'] || '__EXTERNAL_PAYMENT__'

if ENV['SKIP_GW']
  PLUGIN_PROPERTIES = 'pluginProperty=skip_gw=true'
else
  PLUGIN_PROPERTIES = ENV['PLUGIN_PROPERTIES'] || ''
end

# Usage example: NB_THREADS=10 DURATION=30 SKIP_GW=true PLUGIN=killbill-litle DEBUG=true ruby payment.rb
scenario = test do
  header COMMON_HEADERS

  threads count: NB_THREADS.to_i, rampup: 30, duration: DURATION.to_i, on_sample_error: 'startnextloop' do

    transaction 'Create an account and trigger a payment' do
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

      exists 'account_id' do
        #
        # Add default payment method
        #

        payment_method_body_body = {
            pluginName: PLUGIN,
            pluginInfo: {
                properties: [
                    {key: 'email', value: account[:email]},
                    {key: 'description', value: START_TIME},
                    {key: 'ccFirstName', value: first},
                    {key: 'ccLastName', value: last},
                    {key: 'ccNumber', value: '4242424242424242'},
                    {key: 'ccExpirationYear', value: '2020'},
                    {key: 'ccExpirationMonth', value: '10'},
                ]
            }
        }
        post name: :'Add default Payment Method',
             url: "#{KB_ACCOUNTS_URL}/${account_id}/paymentMethods?isDefault=true&#{PLUGIN_PROPERTIES}",
             raw_path: true,
             raw_body: payment_method_body_body.to_json do
          assert equals: 201, test_field: 'Assertion.response_code'
          extract name: 'payment_method_id',
                  regex: LOCATION_ID_REGEX,
                  headers: true
        end

        exists 'payment_method_id' do
          #
          # Trigger payment
          #

          payment_body = {
              transactionType: 'PURCHASE',
              amount: 10,
              currency: account['currency']
          }
          post name: :"Purchase Payment",
               url: "#{KB_ACCOUNTS_URL}/${account_id}/payments?#{PLUGIN_PROPERTIES}",
               raw_path: true,
               raw_body: payment_body.to_json do
            assert equals: 201, test_field: 'Assertion.response_code'
          end
        end
      end
    end
  end

  set_up_thread_group &DEFAULT_SETUP
  tear_down_thread_group &DEFAULT_TEARDOWN
end

run!(scenario, LOGS_PREFIX)
