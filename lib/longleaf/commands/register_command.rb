require 'longleaf/logging'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/events/register_event'
require 'longleaf/models/file_record'

# Command for registering files with longleaf
module Longleaf
  class RegisterCommand
    include Longleaf::Logging
    
    def initialize(config_path)
      @config_path = config_path
    end

    # Execute the register command on the given parameters
    def execute(file_paths: nil, force: false, checksums: nil)
      if file_paths.nil? || file_paths.empty?
        logger.failure("Must provide one or more file paths to register")
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
            
            register_event = RegisterEvent.new(file_rec: file_rec, force: force, app_manager: app_manager,
                checksums: checksums)
            register_event.perform
            
            logger.success('register', f_path)
          rescue RegistrationError => err
            logger.failure('register', f_path, err.message)
          rescue InvalidStoragePathError => err
            logger.failure('register', f_path, err.message)
          end
        end
      rescue ConfigurationError => err
        logger.failure("Failed to load application configuration due to the following issue:\n#{err.message}")
      rescue => err
        logger.failure('register', error: err)
      end
    end
  end
end