require 'longleaf/helpers/service_date_helper'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/errors'
require 'longleaf/logging'
require 'time'

# Iterator for getting file candidates which have services which need to be run.
# Implementation uses metadata files directly from the filesystem for determinations
# about service status.
module Longleaf
  class ServiceCandidateFilesystemIterator
    include Longleaf::Logging
    
    def initialize(file_selector, app_config)
      @file_selector = file_selector
      @app_config = app_config
    end
    
    # Get the file record for the next candidate which needs services run which match the 
    # provided file_selector
    # @return [FileRecord] file record of the next candidate with services needing to be run,
    #    or nil if there are no more candidates.
    def next_candidate
      loop do
        begin
          next_path = @file_selector.next_path
          return nil if next_path.nil?
          
          logger.debug("Evaluating candidate #{next_path}")
          storage_loc = @app_config.location_manager.get_location_by_path(next_path)
          file_rec = FileRecord.new(next_path, storage_loc)
      
          # Skip over unregistered files
          if !file_rec.registered?
            logger.debug("Ignoring unregistered file #{next_path}")
            next
          end
          
          file_rec.metadata_record = MetadataDeserializer.deserialize(file_path: file_rec.metadata_path)
      
          # Return the file record if it needs any services run
          return file_rec if needs_run?(file_rec)
        rescue InvalidStoragePathError => e
          logger.warn("Skipping candidate file: #{e.message}")
        end
      end
    end
    
    # Iterate through the candidates in this object and execute the provided block with each
    # candidate. A block is required.
    def each
      file_rec = next_candidate
      until file_rec.nil?
        yield file_rec
        
        file_rec = next_candidate
      end
    end
    
    private
    # Returns true if the file record contains any services which need to be run
    def needs_run?(file_rec)
      md_rec = file_rec.metadata_record
      storage_loc = file_rec.storage_location
      
      present_services = md_rec.list_services
      
      expected_services = @app_config.service_manager.list_service_definitions(location: storage_loc.name)
      expected_services.each do |service_def|
        expected_name = service_def.name
        # If service not recorded for file, then it is needed
        return true unless present_services.include?(expected_name)
        
        service_rec = md_rec.service(expected_name)
        return true if service_rec.run_needed
        return true if service_rec.timestamp.nil?
        
        # Check if the amount of time defined in frequency has passed since the service timestamp
        frequency = service_def.frequency
        unless frequency.nil?
          service_timestamp = service_rec.timestamp
          now = Time.now.iso8601.to_s
          
          return true if now > ServiceDateHelper.add_to_timestamp(service_timestamp, frequency)
        end
      end
      
      # No services needed to be run for this file
      false
    end
  end
end