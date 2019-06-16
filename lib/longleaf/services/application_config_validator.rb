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
      defs_result = ServiceDefinitionValidator.new(config).validate_config
      mapping_result = ServiceMappingValidator.new(config).validate_config

      errors = Array.new
      errors.concat(loc_result.errors) unless loc_result.valid?
      errors.concat(defs_result.errors) unless defs_result.valid?
      errors.concat(mapping_result.errors) unless mapping_result.valid?

      if errors.length > 0
        formatted_errors = errors.join("\n")
        multiple = errors.length > 1
        raise ConfigurationError.new("Invalid application configuration due to the following issue#{'s' if multiple}:\n#{formatted_errors}")
      end
    end
  end
end
