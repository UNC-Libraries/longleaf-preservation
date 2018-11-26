require_relative 'storage_location_validator'
require_relative 'storage_location_manager'
require_relative 'service_definition_validator'
require_relative 'service_definition_manager'
require_relative 'service_mapping_validator'
require_relative 'service_mapping_manager'
require_relative 'service_manager'

module Longleaf
  # Manager which loads and provides access to the configuration of the application
  class ApplicationConfigManager
    attr_reader :service_manager
    attr_reader :location_manager
    
    def initialize(config)
      @location_manager = Longleaf::StorageLocationManager.new(config)
      
      definition_manager = Longleaf::ServiceDefinitionManager.new(config)
      mapping_manager = Longleaf::ServiceMappingManager.new(config)
      @service_manager = Longleaf::ServiceManager.new(
          definition_manager: definition_manager, mapping_manager: mapping_manager)
    end
  end
end