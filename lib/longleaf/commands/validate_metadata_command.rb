require 'longleaf/services/application_config_deserializer'
require 'longleaf/models/file_record'
require 'longleaf/events/event_status_tracking'
require 'longleaf/errors'

module Longleaf
  # Command for validating file metadata longleaf
  class ValidateMetadataCommand
    include Longleaf::EventStatusTracking
    
    def initialize(app_manager)
      @app_manager = app_manager
    end

    # Execute the validation command
    # @param file_selector [FileSelector] selector for files to register
    # @return [Integer] status code
    def execute(file_selector:)
      begin
        # Perform metadata validation on each of the file paths provided
        loop do
          f_path = file_selector.next_path
          break if f_path.nil?
          
          storage_location = @app_manager.location_manager.get_location_by_path(f_path)
          
          begin
            file_rec = FileRecord.new(f_path, storage_location)
            unless file_rec.metadata_present?
              raise MetadataError.new("Cannot validate metadata for #{f_path}, file is not registered.")
            end
          
            @app_manager.md_manager.load(file_rec)
            record_success("Metadata for file passed validation: #{f_path}")
          rescue LongleafError => err
            record_failure(err.message)
          end
        end
      rescue RegistrationError, InvalidStoragePathError, StorageLocationUnavailableError => err
        record_failure(err.message)
      rescue => err
        record_failure("Encountered error while validating metadata files", error: err)
      end
      
      return_status
    end
  end
end