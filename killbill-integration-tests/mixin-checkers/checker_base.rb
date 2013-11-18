module KillBillIntegrationTests
  module CheckerBase

    def check_with_nil(exp, val)
      if exp.nil?
        assert_nil(val)
      else
        assert_equal(exp, val)
      end
    end
  end
end