require 'pathname'
require 'longleaf/models/service_fields'
require 'longleaf/models/app_fields'
require 'longleaf/errors'
require_relative 'configuration_validator'

module Longleaf
  # Validates application configuration of service to location mappings
  class ServiceMappingValidator < ConfigurationValidator
    AF ||= Longleaf::AppFields
    
    # Validates service mapping configuration to ensure that it is syntactically and referentially correct.
    # @param config [Hash] hash containing the application configuration
    def self.validate_config(config)
      
      assert("Configuration must be a hash, but a #{config.class} was provided", config.class == Hash)
      assert("Configuration must contain a root '#{AF::SERVICE_MAPPINGS}' key", config.key?(AF::SERVICE_MAPPINGS))
      mappings = config[AF::SERVICE_MAPPINGS]
      return if mappings.nil? || mappings.empty?
      assert("'#{AF::SERVICE_MAPPINGS}' must be an array of mappings", mappings.is_a?(Array))
      
      service_names = config[AF::SERVICES].keys
      location_names = config[AF::LOCATIONS].keys
      
      existing_paths = Array.new
      mappings.each do |mapping|
        assert("Mapping must be a hash, but received #{mapping.inspect} instead", mapping.is_a?(Hash))
        
        validate_mapping_field(AF::LOCATIONS, mapping, location_names)
        validate_mapping_field(AF::SERVICES, mapping, service_names)
      end
    end
    
    private
    def self.validate_mapping_field(field, mapping, valid_values)
      assert("Mapping must contain a '#{field}' field", mapping.key?(field))
      field_values = mapping[field]
      assert("Mapping '#{field}' field must be either a string or an array, but received '#{field_values.inspect}' instead",
          field_values.is_a?(Array) || field_values.is_a?(String))
      assert("Mapping must specify one or more value in the '#{field}' field", !field_values.empty?)
      
      check_values = field_values.is_a?(String) ? [field_values] : field_values
      check_values.each do |value|
        assert("Mapping '#{field}' specifies value '#{value}', but no #{field} with that name exist",
            valid_values.include?(value))
      end
    end
  end
end