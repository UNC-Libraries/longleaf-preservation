require 'longleaf/services/application_config_deserializer'
require 'longleaf/events/event_status_tracking'

module Longleaf
  # Command for validating an application configuration file
  class ValidateConfigCommand
    include Longleaf::EventStatusTracking
    
    def initialize(config_path)
      @config_path = config_path
    end
    
    # Execute the validate command on the specified configuration yml file
    def execute
      begin
        app_config_manager = Longleaf::ApplicationConfigDeserializer.deserialize(@config_path)
        
        location_manager = app_config_manager.location_manager
        location_manager.locations.each do |name, location|
          location.available?
        end
        
        record_success("Application configuration passed validation: #{@config_path}")
      rescue Longleaf::ConfigurationError, Longleaf::StorageLocationUnavailableError => err
        record_failure("Application configuration invalid due to the following issue:\n#{err.message}")
      rescue => err
        record_failure("Failed to validate application configuration", error: err)
      end
      
      return_status
    end
  end
end