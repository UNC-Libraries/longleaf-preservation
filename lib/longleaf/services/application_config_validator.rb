require_relative 'storage_location_validator'
require_relative 'service_definition_validator'
require_relative 'service_mapping_validator'

module Longleaf
  # Validator for Longleaf application configuration
  class ApplicationConfigValidator
    # Validates the application configuration provided. Will raise ConfigurationError
    # if any portion of the configuration is not syntactically or semantically valid.
    # @param config [Hash] application configuration
    def self.validate(config)
      loc_result = StorageLocationValidator.new(config).validate_config
      # Longleaf::ServiceDefinitionValidator::validate_config(config)
#       Longleaf::ServiceMappingValidator::validate_config(config)

      if !loc_result.valid?
        loc_errors = loc_result.errors.join("\n")
        multiple = loc_errors.length > 1
        raise ConfigurationError.new("Invalid application configuration due to the following issue#{'s' if multiple}:\n#{loc_errors}")
      end
    end
  end
end
