require_relative 'storage_location_validator'
require_relative 'service_definition_validator'
require_relative 'service_mapping_validator'

# Validator for Longleaf application configuration
module Longleaf
  class ApplicationConfigValidator
    
    # Validates the application configuration provided. Will raise ConfigurationError
    # if any portion of the configuration is not syntactically or semantically valid.
    # @param config [Hash] application configuration
    def self.validate(config)
      Longleaf::StorageLocationValidator::validate_config(config)
      Longleaf::ServiceDefinitionValidator::validate_config(config)
      Longleaf::ServiceMappingValidator::validate_config(config)
    end
  end
end