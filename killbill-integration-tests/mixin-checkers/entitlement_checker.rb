# frozen_string_literal: true

require 'checker_base'
require 'date'
require 'time'
require 'tzinfo'

module KillBillIntegrationTests
  module EntitlementChecker
    include CheckerBase

    def check_subscription(s, product_name, product_category, billing_period, price_list, start_date, cancelled_date, billing_start_date, billing_end_date, account_time_zone = nil)
      check_entitlement(s, product_name, product_category, billing_period, price_list, start_date, cancelled_date, account_time_zone)
      if account_time_zone
        check_with_nil(billing_start_date, (TZInfo::Timezone.get(account_time_zone).utc_to_local(Time.parse(s.billing_start_date)).to_date.to_s if s.billing_start_date))
        check_with_nil(billing_end_date, (TZInfo::Timezone.get(account_time_zone).utc_to_local(Time.parse(s.billing_end_date)).to_date.to_s if s.billing_end_date))
      else
        check_with_nil(billing_start_date, (s.billing_start_date.partition('T')[0] if s.billing_start_date))
        check_with_nil(billing_end_date, (s.billing_end_date.partition('T')[0] if s.billing_end_date))
      end
    end

    def check_entitlement(e, product_name, product_category, billing_period, price_list, start_date, cancelled_date, account_time_zone = nil)
      check_with_nil(product_name, e.product_name)
      check_with_nil(product_category, e.product_category)
      check_with_nil(billing_period, e.billing_period)
      check_with_nil(price_list, e.price_list)
      if account_time_zone
        check_with_nil(start_date, (TZInfo::Timezone.get(account_time_zone).utc_to_local(Time.parse(e.start_date)).to_date.to_s if e.start_date))
        check_with_nil(cancelled_date, (TZInfo::Timezone.get(account_time_zone).utc_to_local(Time.parse(e.cancelled_date)).to_date.to_s if e.cancelled_date))
      else
        check_with_nil(start_date, (e.start_date.partition('T')[0] if e.start_date))
        check_with_nil(cancelled_date, (e.cancelled_date.partition('T')[0] if e.cancelled_date))
      end
    end

    def check_events(expected, real)
      assert_equal(expected.size, real.size, real)
      expected.each_with_index do |e, i|
        assert_equal(e[:type], real[i].event_type) if e.key?(:type)
        assert_equal(e[:date], real[i].effective_date.partition('T')[0]) if e.key?(:date)
        assert_equal(e[:billing_period], real[i].billing_period) if e.key?(:billing_period)
        assert_equal(e[:product], real[i].product) if e.key?(:product)
        assert_equal(e[:plan], real[i].plan) if e.key?(:plan)
        assert_equal(e[:phase], real[i].phase) if e.key?(:phase)
        assert_equal(e[:price_list], real[i].price_list) if e.key?(:price_list)
        assert_equal(e[:is_blocked_billing], real[i].is_blocked_billing) if e.key?(:is_blocked_billing)
        assert_equal(e[:is_blocked_entitlement], real[i].is_blocked_entitlement) if e.key?(:is_blocked_entitlement)
        assert_equal(e[:service_name], real[i].service_name) if e.key?(:service_name)
        assert_equal(e[:service_state_name], real[i].service_state_name) if e.key?(:service_state_name)
      end
    end
  end
end
