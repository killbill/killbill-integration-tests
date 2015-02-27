$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationSeed

  class TestSeedBase < KillBillIntegrationTests::Base

    def setup_seed_base(init_clock)

      tenant_info = {}
      tenant_info[:use_multi_tenant] = true
      tenant_info[:create_multi_tenant] = false
      tenant_info[:external_key] = 'SEED_KEY'
      tenant_info[:api_key] = 'SEED_API_KEY'
      tenant_info[:api_secret] = 'SEED_API_$3CR3T'
      setup_base(self.method_name, tenant_info, init_clock)
    end
  end
end

