require 'longleaf/services/application_config_deserializer'
require 'longleaf/events/deregister_event'
require 'longleaf/models/file_record'
require 'longleaf/events/event_names'
require 'longleaf/events/event_status_tracking'

module Longleaf
  # Command for deregistering files with longleaf
  class DeregisterCommand
    include Longleaf::EventStatusTracking
    
    def initialize(app_manager)
      @app_manager = app_manager
    end

    # Execute the deregister command on the given parameters
    # @param file_selector [FileSelector] selector for files to deregister
    # @param force [Boolean] force flag
    # @return [Integer] status code
    def execute(file_selector:, force: false)
      start_time = Time.now
      logger.info('Performing deregister command')
      begin
        # Perform deregister events on each of the file paths provided
        loop do
          f_path = file_selector.next_path
          break if f_path.nil?
          
          storage_location = @app_manager.location_manager.get_location_by_path(f_path)
        
          file_rec = FileRecord.new(f_path, storage_location)
          unless file_rec.metadata_present?
            raise DeregistrationError.new("Cannot deregister #{f_path}, file is not registered.")
          end
          
          @app_manager.md_manager.load(file_rec)
          
          event = DeregisterEvent.new(file_rec: file_rec, force: force, app_manager: @app_manager)
          track_status(event.perform)
        end
      rescue RegistrationError, DeregistrationError, InvalidStoragePathError, StorageLocationUnavailableError => err
        record_failure(EventNames::DEREGISTER, nil, err.message)
      rescue => err
        record_failure(EventNames::DEREGISTER, error: err)
      end
      
      logger.info("Completed deregister command in #{Time.now - start_time}s")
      return_status
    end
  end
end