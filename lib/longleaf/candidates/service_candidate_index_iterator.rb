require 'longleaf/events/event_names'
require 'longleaf/errors'
require 'longleaf/logging'
require 'time'

module Longleaf
  # Iterator for getting file candidates which have services which need to be run.
  # Implementation uses an index of file metadata to determine if the file needs any
  # services run.
  class ServiceCandidateIndexIterator
    include Longleaf::Logging
    
    def initialize(file_selector, event, app_config, force = false)
      @file_selector = file_selector
      @event = event
      @app_config = app_config
      @force = force
      @index_manager = @app_config.index_manager
      @stale_datetime = Time.now.utc
      @result_set = nil
    end
    
    # Get the file record for the next candidate which needs services run which match the 
    # provided file_selector
    # @return [FileRecord] file record of the next candidate with services needing to be run,
    #    or nil if there are no more candidates.
    def next_candidate
      # Get the next page of results if the previous page has been processed
      if @result_set.nil? || @result_set.empty?
        if @force
          @result_set = @index_manager.registered_paths(@file_selector)
        else
          case(@event)
          when EventNames::PRESERVE
            @result_set = @index_manager.paths_with_stale_services(@file_selector, @stale_datetime)
          when EventNames::CLEANUP
            # TODO
          end
        end
        logger.debug("Retrieve result set with #{@result_set&.length} entries")
      end
      
      next_path = @result_set.shift
      return nil if next_path.nil?
      
      logger.debug("Retrieved candidate #{next_path}")
      storage_loc = @app_config.location_manager.get_location_by_path(next_path)
      file_rec = FileRecord.new(next_path, storage_loc)
  
      # Skip over unregistered files
      if !file_rec.metadata_present?
        logger.warn("Encountered #{next_path} in index, but path is not registered. Clearing out of synch entry.")
        @index_manager.remove(file_rec)
        return next_candidate
      end
      
      file_rec.metadata_record = MetadataDeserializer.deserialize(file_path: file_rec.metadata_path,
          digest_algs: storage_loc.metadata_digests)
      
      file_rec
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
  end
end