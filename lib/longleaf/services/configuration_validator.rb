module Longleaf
  # Abstract configuration validator class
  class ConfigurationValidator
    class << self
      protected
      def assert(fail_message, assertion_passed)
        raise ConfigurationError.new(fail_message) unless assertion_passed
      end
    end
  end
end
