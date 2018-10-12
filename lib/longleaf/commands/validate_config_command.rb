require 'longleaf/logging'
require 'longleaf/services/application_config_deserializer'

module Longleaf
  class ValidateConfigCommand
    include Longleaf::Logging
    
    def initialize(config_path)
      @config_path = config_path
    end
    
    def perform
      begin
        app_config_manager = Longleaf::ApplicationConfigDeserializer.deserialize(@config_path)
        
        location_manager = app_config_manager.location_manager
        location_manager.locations.each do |name, location|
          location.available?
        end
        
        logger.success("Application configuration passed validation: #{@config_path}")
      rescue Longleaf::ConfigurationError, Longleaf::StorageLocationUnavailableError => err
        logger.failure("Application configuration invalid due to the following issue:\n#{err.message}")
      rescue => err
        logger.failure("Failed to validate application configuration", error: err)
      end
    end
  end
end