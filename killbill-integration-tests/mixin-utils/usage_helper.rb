# frozen_string_literal: true

module KillBillIntegrationTests
  module UsageHelper
    #
    # usage_input = [{:unit_type, :usage_records}], and usage_records = [:record_date, :amount]
    #
    def record_usage(subscription_id, usage_input, user, options)
      result = KillBillClient::Model::UsageRecord.new
      result.subscription_id = subscription_id
      result.unit_usage_records = []
      usage_input.each do |e|
        unit_usage_record = KillBillClient::Model::UnitUsageRecordAttributes.new
        unit_usage_record.unit_type = e[:unit_type]
        unit_usage_record.usage_records = []
        e[:usage_records].each do |r|
          usage_record = KillBillClient::Model::UsageRecordAttributes.new
          # Create a timestamp in such a way that if we get a point aliogned with the first transition, the usage point is taken into account:
          # Since our framework initializes the clock with DEFAULT_KB_INIT_CLOCK (see test_base.rb), we use the the same time component here.
          usage_record.record_date = "#{r[:record_date]}T06:00:02.000Z"
          usage_record.amount = r[:amount]
          unit_usage_record.usage_records << usage_record
        end
        result.unit_usage_records << unit_usage_record
      end
      result.create(user, nil, nil, options)
    end

    def get_usage_for_subscription(subscription_id, start_date, end_date, options)
      KillBillClient::Model::RolledUpUsage.find_by_subscription_id(subscription_id, start_date, end_date, options)
    end

    def get_usage_for_subscription_and_type(subscription_id, start_date, end_date, unit_type, options)
      KillBillClient::Model::RolledUpUsage.find_by_subscription_id_and_type(subscription_id, start_date, end_date, unit_type, options)
    end
  end
end
