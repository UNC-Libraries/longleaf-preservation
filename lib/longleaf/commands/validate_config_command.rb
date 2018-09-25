require 'longleaf/services/application_config_deserializer'

module Longleaf
  class ValidateConfigCommand
    
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
        
        puts "Success, application configuration passed validation: #{@config_path}"
      rescue Longleaf::ConfigurationError, Longleaf::StorageLocationUnavailableError => err
        puts "Application configuration invalid due to the following issue:"
        puts err.message
      rescue => err
        puts "Failed to validate application configuration:"
        puts err.message
        puts err.backtrace
      end
    end
  end
end