require 'longleaf/services/application_config_deserializer'
require 'longleaf/events/register_event'
require 'longleaf/models/file_record'

# Command for registering files with longleaf
module Longleaf
  class RegisterCommand
    
    def initialize(config_path)
      @config_path = config_path
    end

    # Execute the register command on the given parameters
    def execute(file_paths: nil, force: false)
      if file_paths.nil? || file_paths.empty?
        puts "Must provide one or more file paths to register"
        return
      end
      
      begin
        # Retrieve the application configuration
        app_manager = Longleaf::ApplicationConfigDeserializer.deserialize(@config_path)
        
        # Perform register events on each of the file paths provided
        file_paths.each do |f_path|
          begin
            storage_location = app_manager.location_manager.get_location_by_path(f_path)
            if storage_location.nil?
              raise InvalidStoragePathError.new(
                  "Unable to register '#{f_path}', it does not belong to any registered storage locations.")
            end
          
            raise InvalidStoragePathError.new("Unable to register '#{f_path}', file does not exist or is unreachable.") \
                unless File.file?(f_path)
          
            file_rec = FileRecord.new(f_path, storage_location)
            
            register_event = RegisterEvent.new(file_rec: file_rec, force: force, app_manager: app_manager)
            register_event.perform
            
            puts "Registered: #{f_path}"
          rescue RegistrationError => err
            puts err.message
          rescue InvalidStoragePathError => err
            puts err.message
          end
        end
      rescue ConfigurationError => err
        puts "Failed to load application configuration due to the following issue:"
        puts err.message
      rescue => err
        puts "Failed to perform register event:"
        puts err.message
        puts err.backtrace
      end
    end
  end
end