require_relative 'storage_location_validator'
require_relative 'service_definition_validator'
require_relative 'service_mapping_validator'

module Longleaf
  # Validator for Longleaf application configuration
  class ApplicationConfigValidator < ConfigurationValidator
    # @param config [Hash] hash containing the application configuration
    def initialize(config)
      super(config)
    end

    protected
    # Validates the application configuration provided. Will raise ConfigurationError
    # if any portion of the configuration is not syntactically or semantically valid.
    def validate
      loc_result = StorageLocationValidator.new(@config).validate_config
      defs_result = ServiceDefinitionValidator.new(@config).validate_config
      mapping_result = ServiceMappingValidator.new(@config).validate_config

      @result.errors.concat(loc_result.errors) unless loc_result.valid?
      @result.errors.concat(defs_result.errors) unless defs_result.valid?
      @result.errors.concat(mapping_result.errors) unless mapping_result.valid?

      @result
    end
  end
end
