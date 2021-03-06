require_relative 'storage_location_validator'
require_relative 'storage_location_manager'
require_relative 'service_definition_validator'
require_relative 'service_definition_manager'
require_relative 'service_mapping_validator'
require_relative 'service_mapping_manager'
require_relative 'service_manager'
require_relative 'metadata_persistence_manager'
require 'longleaf/indexing/index_manager'
require 'longleaf/models/app_fields'

module Longleaf
  # Manager which loads and provides access to the configuration of the application
  class ApplicationConfigManager
    attr_reader :config_md5
    attr_reader :service_manager
    attr_reader :location_manager
    attr_reader :index_manager
    attr_reader :md_manager

    def initialize(config, config_md5 = nil)
      @config_md5 = config_md5

      @location_manager = Longleaf::StorageLocationManager.new(config)

      definition_manager = Longleaf::ServiceDefinitionManager.new(config)
      mapping_manager = Longleaf::ServiceMappingManager.new(config)
      @service_manager = Longleaf::ServiceManager.new(
          definition_manager: definition_manager,
          mapping_manager: mapping_manager,
          app_manager: self)

      sys_config = config[AppFields::SYSTEM]
      @index_manager = IndexManager.new(sys_config, self)
      @md_manager = MetadataPersistenceManager.new(@index_manager)
    end
  end
end
