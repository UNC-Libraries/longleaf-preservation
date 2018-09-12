require_relative '../models/app_fields'
require_relative '../models/service_definition'

# Manager which loads and provides access to Longleaf::ServiceDefinition objects
module Longleaf
  class ServiceDefinitionManager
    SF ||= Longleaf::ServiceFields
    AF ||= Longleaf::AppFields
    
    attr_reader :services
    
    def initialize(config)
      raise ArgumentError.new("Configuration must be provided") if config.nil? || config.empty?

      services_config = config[AF::SERVICES]
      raise ArgumentError.new("Services configuration must be provided") if services_config.nil?
      
      @services = Hash.new
      config[AF::SERVICES].each do |name, properties|
        work_script = properties.delete(SF::WORK_SCRIPT)
        frequency = properties.delete(SF::FREQUENCY)
        delay = properties.delete(SF::DELAY)
        service = Longleaf::ServiceDefinition.new(
            name: name,
            work_script: work_script,
            frequency: frequency,
            delay: delay,
            properties: properties)
        
        @services[name] = service
      end
      @services.freeze
    end
    
  end
end