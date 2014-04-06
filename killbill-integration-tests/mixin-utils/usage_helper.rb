module KillBillIntegrationTests
  module UsageHelper

    def record_usage(subscription_id, unit_type, start_time, end_time, amount, user, options)
      result = KillBillClient::Model::Usage.new
      result.subscription_id =  subscription_id
      result.unit_type =  unit_type
      result.start_time =  start_time
      result.end_time =  end_time
      result.amount =  amount
      result.create(user, nil, nil, options)
    end

    def get_usage_for_subscription(subscription_id, options)
      KillBillClient::Model::Usage.find_by_subscription_id(subscription_id, options)
    end
  end
end