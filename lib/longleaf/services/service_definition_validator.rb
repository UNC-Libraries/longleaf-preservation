require 'pathname'
require 'longleaf/models/service_fields'
require 'longleaf/models/app_fields'
require 'longleaf/errors'
require_relative 'configuration_validator'

module Longleaf
  # Validates application configuration of service definitions
  class ServiceDefinitionValidator < ConfigurationValidator
    SF ||= Longleaf::ServiceFields
    AF ||= Longleaf::AppFields
    
    # Validates configuration to ensure that it is syntactically correct and does not violate 
    # schema requirements.
    # @param config [Hash] hash containing the application configuration
    def self.validate_config(config)
      assert("Configuration must be a hash, but a #{config.class} was provided", config.class == Hash)
      assert("Configuration must contain a root '#{AF::SERVICES}' key", config.key?(AF::SERVICES))
      services = config[AF::SERVICES]
      assert("'#{AF::SERVICES}' must be a hash of services", services.class == Hash)
      
      existing_paths = Array.new
      services.each do |name, properties|
        assert("Name of service definition must be a string, but was of type #{name.class}", name.instance_of?(String))
        assert("Service definition '#{name}' must be a hash, but a #{properties.class} was provided", properties.is_a?(Hash))
        
        work_script = properties[SF::WORK_SCRIPT]
        assert("Service definition '#{name}' must specify a '#{SF::WORK_SCRIPT}' property", !work_script.nil? && !work_script.empty?)
      end
    end
  end
end