require 'sequel'
require 'digest/md5'
require 'longleaf/events/event_names'
require 'longleaf/candidates/file_selector'
require 'longleaf/version'
require 'longleaf/models/system_config_fields'
require 'longleaf/logging'

module Longleaf
  # Driver for interacting with RDBM based metadata index using the Sequel ORM gem.
  # Users must create the database and credentials for connecting to it in advance,
  # if using a database application that requires creation of databases (ie, not sqlite).
  # The default database name is 'longleaf_metadata_index' but may be overridden.
  #
  # See the Sequel documentation for details about accepted connection parameters:
  # https://github.com/jeremyevans/sequel/blob/master/doc/opening_databases.rdoc
  class SequelIndexDriver
    include Longleaf::Logging
    INDEX_DB_NAME ||= 'longleaf_metadata_index'
    PRESERVE_TBL ||= "preserve_service_times".to_sym
    INDEX_STATE_TBL ||= "index_state".to_sym
    DEFAULT_PAGE_SIZE ||= 1000
    TIMESTAMP_FORMAT ||= '%Y-%m-%d %H:%M:%S.%3N'
   
    # Initialize the index driver
    #
    # @param app_config [ApplicationConfigManager] the application configuration manager
    # @param adapter [String] name of the database adapter to use.
    # @param conn_details Details about the configuration and connection to the database used for the index.
    #    If a string is provided, it will be used as the connection URL and must identify the adapter.
    #    If a hash is provided, it used as the parameters for the database connection.
    # @param page_size [Integer] number of results to retrieve per query when getting candidates
    def initialize(app_config, adapter, conn_details, page_size: nil)
      Sequel.default_timezone = :utc
      @app_config = app_config
      @adapter = adapter
      @conn_details = conn_details
      # Digest of the app config file so we can tell if it changes
      @config_md5 = app_config.config_md5
      @page_size = page_size.nil? || page_size <= 0 ? DEFAULT_PAGE_SIZE : page_size
      
      if @conn_details.is_a?(Hash)
        # Add in the adapter name
        @conn_details['adapter'] = adapter unless @conn_details.key?('adapter')
        # Add in default database name if none was specified
        @conn_details['database'] = INDEX_DB_NAME unless @conn_details.key?('database')
      end
    end
    
    # Returns true if the application configuration does not match the configuration used for
    # the last reindex.
    def is_stale?
      db_conn[INDEX_STATE_TBL].where(config_md5: @config_md5).count == 0
    end
    
    # Index the provided file_rec and its metadata
    #
    # @param file_rec [FileRecord] file record to index
    def index(file_rec)
      file_path = file_rec.path
      md_rec = file_rec.metadata_record
      storage_loc = file_rec.storage_location
      service_manager = @app_config.service_manager
      
      # Produce a list of service definitions which should apply to the file
      expected_services = service_manager.list_service_definitions(
          location: storage_loc.name)
      
      first_timestamp = first_service_execution_timestamp(expected_services, md_rec)
      delay_until_timestamp = delay_until_timestamp(md_rec)

      first_timestamp = convert_iso8601_to_timestamp(first_timestamp)
      delay_until_timestamp = convert_iso8601_to_timestamp(delay_until_timestamp)
      now_stamp = Time.now.utc.strftime(TIMESTAMP_FORMAT)
      
      if @adapter == :mysql || @adapter == :mysql2
        preserve_tbl.on_duplicate_key_update
            .insert(file_path: file_path,
                storage_location: storage_loc.name,
                service_time: first_timestamp,
                delay_until_time: delay_until_timestamp,
                updated: now_stamp)
      else
        preserve_tbl.insert_conflict(target: :file_path,
            update: {
                storage_location: storage_loc.name,
                service_time: first_timestamp,
                delay_until_time: delay_until_timestamp,
                updated: now_stamp } )
            .insert(file_path: file_path,
                storage_location: storage_loc.name,
                service_time: first_timestamp,
                delay_until_time: delay_until_timestamp,
                updated: now_stamp)
      end
    end
    
    # Find the earliest service execution time for any services expected to be run for the specified file.
    #
    # @param expected_services [Array] list of ServiceDefinition objects expected for specified file.
    # @param md_rec [MetadataRecord] metadata record for the file being evaluated
    # @return The timestamp of the earliest service execution time for the file described by md_rec, in iso8601 format.
    #    Returns nil if no services are expected all services have already run and do not have a next occurrence, or
    #    the file is deregistered.
    def first_service_execution_timestamp(expected_services, md_rec)
      current_time = Time.now.utc.iso8601(3)
      if md_rec.deregistered?
        return nil
      end
      
      service_times = Array.new
      
      present_services = md_rec.list_services
      
      expected_services.each do |service_def|
        service_name = service_def.name
        # Service has never run, set execution time to now
        if !present_services.include?(service_name)
          service_times << current_time
          next
        end
      
        service_rec = md_rec.service(service_name)
      
        # Service either needs a run or has no timestamp, so execution time of now
        if service_rec.run_needed || service_rec.timestamp.nil?
          service_times << current_time
          next
        end
      
        # Calculate the next time this service should run based on frequency
        frequency = service_def.frequency
        unless frequency.nil?
          service_timestamp = service_rec.timestamp
          service_times << ServiceDateHelper.add_to_timestamp(service_timestamp, frequency)
          next
        end
      end
      # Return the lowest service execution time
      service_times.min
    end
    
    # @return The first failure timestamp for any service, or nil if there were none.
    def delay_until_timestamp(md_rec)
      md_rec.list_services.each do |service_name|
        service_rec = md_rec.service(service_name)
        return service_rec.failure_timestamp unless service_rec.failure_timestamp.nil?
      end
      # return lowest possible date
      return minimum_timestamp
    end
    
    # Remove an entry from the index
    # @param remove_me The record to remove from the index. May be a FileRecord or a String.
    def remove(remove_me)
      if remove_me.is_a?(FileRecord)
        path = remove_me.path
      else
        path = remove_me
      end
      
      result = preserve_tbl.where(file_path: path).delete
      if result == 0
        logger.warn("Could not remove #{path} from the index, path was not present.")
      end
    end
    
    # Remove all entries from the index
    # @param older_than [Time] Optional. If provided, only entries that have not been indexed
    #    since before the provided time will be deleted.
    def clear_index(older_than = nil)
      if older_than.nil?
        preserve_tbl.delete
      else
        older_than_timestamp = older_than.utc.strftime(TIMESTAMP_FORMAT)
        preserve_tbl.where { updated < older_than_timestamp }.delete
      end
    end
    
    # Initialize the index's database using the provided configuration
    def setup_index
      # Create the table for tracking when files will need preservation services run on them.
      case(@adapter)
      when :mysql, :mysql2
        # mysql does not support 'text' fields as primary keys
        db_conn.create_table!(PRESERVE_TBL) do
          String :file_path, primary_key: true, size: 768
          column :storage_location, 'varchar(128)'
          column :service_time, 'timestamp(3)', { :null => true }
          column :delay_until_time, 'timestamp(3)'
          column :updated, 'timestamp(3)'
        end
      else
        db_conn.create_table!(PRESERVE_TBL) do
          String :file_path, primary_key: true, text: true
          column :storage_location, 'varchar(128)'
          column :service_time, 'timestamp(3)', { :null => true }
          column :delay_until_time, 'timestamp(3)'
          column :updated, 'timestamp(3)'
        end
      end
  
      # Setup database indexes
      case(@adapter)
      when :postgres
        db_conn.run("CREATE INDEX service_times_file_path_text_index ON preserve_service_times (file_path text_pattern_ops)")
      when :sqlite, :amalgalite
        db_conn.run("CREATE INDEX service_times_file_path_text_index ON preserve_service_times (file_path collate nocase)")
      end
      db_conn.run("CREATE INDEX service_times_storage_location_index ON preserve_service_times (storage_location)")
      
      # Create table for tracking the state of the index
      db_conn.create_table!(INDEX_STATE_TBL) do
        String :config_md5
        DateTime :last_reindexed
        String :longleaf_version
      end
      
      # Prepopulate the index state information
      update_index_state
    end
    
    # Updates the state information for the index to indicate that the index has been refreshed
    # or is in sync with the application's configuration.
    def update_index_state
      index_state_tbl = db_conn[INDEX_STATE_TBL]
      index_state_tbl.delete
      index_state_tbl.insert(
          config_md5: @config_md5,
          last_reindexed: Time.now.utc,
          longleaf_version: Longleaf::VERSION)
    end
    
    # Retrieves page of file paths which have one or more services which need to run.
    # @param file_selector [FileSelector] selector for what paths to search for files
    # @param stale_datetime [DateTime] find file_paths with services needing to be run before this value
    # @return [Array] array of file paths that need one or more services run.
    def paths_with_stale_services(file_selector, stale_datetime)
      if @preserve_dataset.nil?
        @preserve_dataset = db_conn
            .from(PRESERVE_TBL)
            .exclude(service_time: nil)
            .limit(@page_size)
            .order(Sequel.asc(:service_time))
      end
      
      # retrieve and return a page of results
      ds = add_path_restrictions(@preserve_dataset, file_selector)
          .where { service_time <= stale_datetime }
          .where { delay_until_time < stale_datetime }
          .select_map(:file_path)
    end
    
    # Retrieves a page of paths for registered files.
    # @param file_selector [FileSelector] selector for what paths to search for files
    # @return [Array] array of file paths that are registered
    def registered_paths(file_selector)
      # retrieve and return a page of results
      add_path_restrictions(registered_dataset, file_selector)
          .select_map(:file_path)
    end
    
    # Calls the provided block once per each registered file path registered.
    # Must be passed a block.
    # @param file_selector [FileSelector] selector for what paths to search for files
    # @param older_than [Time] Optional. If provided, only files that have not been
    #    indexed since before this timestamp will be returned.
    def each_registered_path(file_selector, older_than: nil, &block)
      dataset = add_path_restrictions(registered_dataset, file_selector)
          .select(:file_path)
      if !older_than.nil?
        older_than_timestamp = older_than.utc.strftime(TIMESTAMP_FORMAT)
        dataset = dataset.where { updated < older_than_timestamp }
      end
      # Yield to the provided block once per row return
      dataset.paged_each(:rows_per_fetch => @page_size) do |row|
        block.call(row[:file_path])
      end
    end
    
    private
    def db_conn
      @connection = Sequel.connect(@conn_details) if @connection.nil?
      @connection
    end
    
    def preserve_tbl
      @preserve_tbl = db_conn[PRESERVE_TBL] if @preserve_tbl.nil?
      @preserve_tbl
    end
    
    def add_path_restrictions(dataset, file_selector)
      if file_selector.specificity == FileSelector::SPECIFICITY_STORAGE_LOCATION
        dataset.where(storage_location: file_selector.storage_locations)
      else
        # Reformat all selected paths into LIKE partial string matches
        path_conds = file_selector.target_paths.map { |path| path.end_with?('/') ? path + '%' : path }
        dataset.where(Sequel.like(:file_path, *path_conds))
      end
    end
    
    def convert_iso8601_to_timestamp(iso8601)
      return nil if iso8601.nil?
      Time.iso8601(iso8601).strftime(TIMESTAMP_FORMAT)
    end
    
    def minimum_timestamp
      if @min_timestamp.nil?
        @min_timestamp = ServiceDateHelper.formatted_timestamp(Time.at(0).utc)
      end
      @min_timestamp
    end
    
    def registered_dataset
      if @registered_dataset.nil?
        @registered_dataset = db_conn
            .from(PRESERVE_TBL)
            .limit(@page_size)
            .order(Sequel.asc(:service_time))
      end
      @registered_dataset
    end
  end
end