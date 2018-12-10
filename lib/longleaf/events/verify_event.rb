require 'longleaf/services/service_manager'
require 'longleaf/events/event_names'

module Longleaf
  # Verify event for a single file
  class VerifyEvent
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
      
      service_performed = false
      begin
        # get the list of services applicable to this location and event
        service_manager.list_services(location: storage_loc, event: EventNames::VERIFY).each do |service_name|
          # Skip over this service if it does not need to be run, unless force flag active
          unless @force || service_manager.service_needed?(service_name, md_rec)
            next
          end
        
          # execute the service
          service_manager.perform_service(service_name, @file_rec, EventNames::VERIFY)
          @file_rec.metadata_record.update_service_as_performed(service_name)
          service_performed = true
        end
      ensure
        # persist the metadata out to file if any services were executed
        if service_performed
          MetadataSerializer::write(metadata: @file_rec.metadata_record, file_path: @file_rec.metadata_path)
        end
      end
    end
  end
end