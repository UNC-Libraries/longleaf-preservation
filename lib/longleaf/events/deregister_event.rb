require 'longleaf/errors'
require 'longleaf/events/event_names'
require 'longleaf/events/event_status_tracking'
require 'longleaf/services/metadata_serializer'

module Longleaf
  # Event to deregister a file from longleaf
  class DeregisterEvent
    include Longleaf::EventStatusTracking
    
    # @param file_rec [FileRecord] file record
    # @param app_manager [ApplicationConfigManager] the application configuration
    # @param force [boolean] if true, then already deregistered files will be deregistered again
    def initialize(file_rec:, app_manager:, force: false)
      raise ArgumentError.new('Must provide a file_rec parameter') if file_rec.nil?
      raise ArgumentError.new('Parameter file_rec must be a FileRecord') \
          unless file_rec.is_a?(FileRecord)
      raise ArgumentError.new('Must provide an ApplicationConfigManager') if app_manager.nil?
      raise ArgumentError.new('Parameter app_manager must be an ApplicationConfigManager') \
          unless app_manager.is_a?(ApplicationConfigManager)
      
      @app_manager = app_manager
      @file_rec = file_rec
      @force = force
    end
    
    # Perform a deregistration event on the given file record
    # @raise DeregistrationError if a file cannot be deregistered 
    def perform
      begin
        md_rec = @file_rec.metadata_record
        
        # Only need to deregister a deregistered file if the force flag is provided
        if md_rec.deregistered? && !@force
          raise DeregistrationError.new("Unable to deregister '#{@file_rec.path}', it is already deregistered.")
        end
        
        md_rec.deregistered = Time.now.utc.iso8601
        
        # persist the metadata
        @app_manager.md_manager.persist(@file_rec)
        
        record_success(EventNames::DEREGISTER, @file_rec.path)
      rescue DeregistrationError => err
        record_failure(EventNames::DEREGISTER, @file_rec.path, err.message)
      rescue InvalidStoragePathError => err
        record_failure(EventNames::DEREGISTER, @file_rec.path, err.message)
      end
      
      return_status
    end
  end
end