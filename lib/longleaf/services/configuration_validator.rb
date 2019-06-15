module Longleaf
  # Abstract configuration validator class
  class ConfigurationValidator
    attr_reader :result

    def initialize(config)
      @result = ConfigurationValidationResult.new
      @config = config
    end

    # Verify that the provided configuration is valid
    # @return [ConfigurationValidationResult] the result of the validation
    def validate_config
      register_on_failure { validate }

      @result
    end

    protected
    # Asserts that the given conditional is true, raising a ConfigurationError if it is not.
    def assert(fail_message, assertion_passed)
      fail(fail_message) unless assertion_passed
    end

    # Indicate that validation has failed, throwing a Configuration error with the given message
    def fail(fail_message)
      raise ConfigurationError.new(fail_message)
    end

    # Registers an error to the result for this validator
    def register_error(error)
      if error.is_a?(StandardError)
        @result.register_error(error.msg)
      else
        @result.register_error(error)
      end
    end

    # Performs the provided block. If the block produces a ConfigurationError, the error
    # is swallowed and registered to the result
    def register_on_failure
      begin
        yield
      rescue ConfigurationError => err
        register_error(err.message)
      end
    end
  end

  class ConfigurationValidationResult
    attr_reader :errors

    def initialize
      @errors = Array.new
    end

    def register_error(error_message)
      @errors << error_message
    end

    def valid?
      @errors.length == 0
    end
  end
end
