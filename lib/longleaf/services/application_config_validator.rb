require_relative 'storage_location_validator'
require_relative 'storage_location_manager'
require_relative 'service_definition_validator'
require_relative 'service_definition_manager'
require_relative 'service_mapping_validator'
require_relative 'service_mapping_manager'

# Validator for Longleaf application configuration
module Longleaf
  class ApplicationConfigValidator
    
    # Validates the application configuration provided
    # @param config [Hash] application configuration
    def self.validate(config)
      validate_storage_locations(config)
      validate_service_definitions(config)
      validate_service_mappings(config)
    end
    
    # Validates storage location configuration, verifying it is syntactically correct,
    # can be deserialized, and the defined locations are available to longleaf.
    #
    # @param config [Hash] application configuration
    def self.validate_storage_locations(config)
      Longleaf::StorageLocationValidator::validate_config(config)
      
      location_manager = Longleaf::StorageLocationManager.new(config)
      
      location_manager.locations.each do |name, location|
        location. validator
      end
    end
    
    # Validates service definition configuration. Verifies it is syntactically correct
    # and deserializable
    # @param config [Hash] application configuration
    def self.validate_service_definitions(config)
      Longleaf::ServiceDefinitionValidator::validate_config(config)
      
      Longleaf::ServiceDefinitionManager.new(config)
    end
    
    # Validates service to location mapping configuration
    # @param config [Hash] application configuration
    def self.validate_service_mappings(config)
      Longleaf::ServiceMappingValidator::validate_config(config)
      
      Longleaf::ServiceMappingManager.new(config)
    end
  end
end