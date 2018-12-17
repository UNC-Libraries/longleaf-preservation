require 'longleaf/services/service_manager'
require 'longleaf/events/event_names'
require 'longleaf/events/event_status_tracking'
require 'longleaf/logging'

module Longleaf
  # Verify event for a single file
  class VerifyEvent
    include Longleaf::Logging
    include Longleaf::EventStatusTracking
    
    # @param file_rec [FileRecord] file record
    # @param app_manager [ApplicationConfigManager] the application configuration
    # @param force [boolean] if true, then services run regardless of whether they are flagged as needed
    def initialize(file_rec:, app_manager:, force: false)
      raise ArgumentError.new('Must provide a file_rec parameter') if file_rec.nil?
      raise ArgumentError.new('Must provide an ApplicationConfigManager') if app_manager.nil?
      
      @app_manager = app_manager
      @file_rec = file_rec
      @force = force
    end
    
    # Perform a verify event on the given file, updating its metadata record if any services were executed.
    def perform
      storage_loc = @file_rec.storage_location
      service_manager = @app_manager.service_manager
      md_rec = @file_rec.metadata_record
      f_path = @file_rec.path
      
      logger.info("Performing verify event on #{@file_rec.path}")
      
      service_performed = false
      begin
        # get the list of services applicable to this location and event
        service_manager.list_services(location: storage_loc.name, event: EventNames::VERIFY).each do |service_name|
          # Skip over this service if it does not need to be run, unless force flag active
          unless @force || service_manager.service_needed?(service_name, md_rec)
            logger.debug("Service #{service_name} not needed for file '#{@file_rec.path}', skipping")
            next
          end
          
          begin
            logger.info("Verifying service #{service_name} for #{@file_rec.path}")
            # execute the service
            service_manager.perform_service(service_name, @file_rec, EventNames::VERIFY)
            
            # record the outcome
            @file_rec.metadata_record.update_service_as_performed(service_name)
            service_performed = true
            record_success(EventNames::VERIFY, f_path, nil, service_name)
          rescue PreservationServiceError => e
            record_failure(EventNames::VERIFY, f_path, e.message, service_name)
          rescue StandardError => e
            record_failure(EventNames::VERIFY, f_path, nil, service_name, error: e)
            return return_status
          end
        end
      ensure
        # persist the metadata out to file if any services were executed
        if service_performed
          MetadataSerializer::write(metadata: @file_rec.metadata_record, file_path: @file_rec.metadata_path)
        end
      end
      
      return_status
    end
  end
end