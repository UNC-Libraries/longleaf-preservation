require_relative '../models/app_fields'
require_relative '../models/service_definition'

module Longleaf
  # Manager which loads and provides access to Longleaf::ServiceDefinition objects
  class ServiceDefinitionManager
    SF ||= Longleaf::ServiceFields
    AF ||= Longleaf::AppFields
    
    # Hash containing the set of configured services, represented as {ServiceDefinition} objects
    attr_reader :services
    
    # @param config [Hash] hash representation of the application configuration
    def initialize(config)
      raise ArgumentError.new("Configuration must be provided") if config.nil? || config.empty?

      services_config = config[AF::SERVICES]
      raise ArgumentError.new("Services configuration must be provided") if services_config.nil?
      
      @services = Hash.new
      config[AF::SERVICES].each do |name, properties|
        work_script = properties.delete(SF::WORK_SCRIPT)
        work_class = properties.delete(SF::WORK_CLASS)
        frequency = properties.delete(SF::FREQUENCY)
        delay = properties.delete(SF::DELAY)
        service = Longleaf::ServiceDefinition.new(
            name: name,
            work_script: work_script,
            work_class: work_class,
            frequency: frequency,
            delay: delay,
            properties: properties)
        
        @services[name] = service
      end
      @services.freeze
    end
    
  end
end