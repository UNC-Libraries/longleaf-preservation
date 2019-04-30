require 'longleaf/errors'
require 'longleaf/events/event_status_tracking'
require 'longleaf/logging'

module Longleaf
  # Command for reindexing metadata
  class ReindexCommand
    include Longleaf::Logging
    include Longleaf::EventStatusTracking
    
    def initialize(app_manager)
      @app_manager = app_manager
      @index_manager = @app_manager.index_manager
    end
    
    # Execute the reindex command
    # @param only_if_stale [boolean] if true, then the reindex command will perform no operation unless the index is stale.
    # @return [Integer] status code
    def execute(only_if_stale: false)
      if !@index_manager.using_index?
        record_failure("Cannot perform reindex, no index is configured")
        return return_status
      end
      
      if only_if_stale && !@index_manager.index_stale?
        record_success("Index is not stale, performing no action")
        return return_status
      end
      
      logger.info('Performing full reindex')
      results = nil
      begin
        # all previous values from the index
        @index_manager.clear_index
        
        # Repopulate the index
        results = index_all_storage_locations
        
        # Update the state of the index to indicate it has been reindexed
        @index_manager.update_index_state
      rescue => err
        record_failure("Encountered error while reindexing", error: err)
      end
      
      if results['fail'] > 0
        record_success("Completed reindexing, #{results['success']} successful, #{results['fail']} failed.")
      else
        record_success("Completed reindexing, #{results['success']} successful.")
      end
      
      return_status
    end
    
    private
    def index_all_storage_locations
      count = 0
      failures = 0
      storage_loc_names = @app_manager.location_manager.locations.keys
      
      selector = RegisteredFileSelector.new(storage_locations: storage_loc_names, app_config: @app_manager)
      selector.each do |file_path|
        begin
          storage_loc = @app_manager.location_manager.get_location_by_path(file_path)
          file_rec = FileRecord.new(file_path, storage_loc)
        
          @app_manager.md_manager.load(file_rec)
          @index_manager.index(file_rec)
        
          record_success("Reindexed #{file_rec.path}")
          count += 1
        rescue LongleafError => err
          record_failure(err.message)
          failures += 1
        end
      end
      {'success' => count, 'fail' => failures}
    end
  end
end