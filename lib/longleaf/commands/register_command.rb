require 'longleaf/services/application_config_deserializer'
require 'longleaf/events/register_event'
require 'longleaf/models/file_record'
require 'longleaf/commands/abstract_command'
require 'longleaf/events/event_names'

# Command for registering files with longleaf
module Longleaf
  class RegisterCommand < AbstractCommand
    
    def initialize(config_path)
      @config_path = config_path
    end

    # Execute the register command on the given parameters
    def execute(file_paths: nil, force: false, checksums: nil)
      if file_paths.nil? || file_paths.empty?
        record_failure("Must provide one or more file paths to register")
        return return_status
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
            
            register_event = RegisterEvent.new(file_rec: file_rec, force: force, app_manager: app_manager,
                checksums: checksums)
            register_event.perform
            
            record_success(EventNames::REGISTER, f_path)
          rescue RegistrationError => err
            record_failure(EventNames::REGISTER, f_path, err.message)
          rescue InvalidStoragePathError => err
            record_failure(EventNames::REGISTER, f_path, err.message)
          end
        end
      rescue ConfigurationError => err
        record_failure("Failed to load application configuration due to the following issue:\n#{err.message}")
      rescue => err
        record_failure(EventNames::REGISTER, error: err)
      end
      
      return_status
    end
  end
end