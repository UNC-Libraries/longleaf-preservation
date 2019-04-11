require 'sequel'
require 'digest/md5'
require 'longleaf/events/event_names'
require 'longleaf/version'

module Longleaf
  # Driver for interacting with RDBM based metadata index using the Sequel ORM gem.
  # Users must create the database and credentials for connecting to it in advance,
  # if using a database application that requires creation of databases (ie, not sqlite).
  # The default database name is 'longleaf_metadata_index' but may be overridden.
  #
  # See the Sequel documentation for details about accepted connection parameters:
  # https://github.com/jeremyevans/sequel/blob/master/doc/opening_databases.rdoc
  class SequelIndexDriver
    INDEX_DB_NAME = 'longleaf_metadata_index'
    PRESERVE_TBL = "preserve_service_times".to_sym
    INDEX_STATE_TBL = "index_state".to_sym
   
    # Initialize the index driver
    #
    # @param app_config [ApplicationConfigManager] the application configuration manager
    # @param adapter [String] name of the database adapter to use.
    # @param conn_details Details about the configuration and connection to the database used for the index.
    #    If a string is provided, it will be used as the connection URL and must identify the adapter.
    #    If a hash is provided, it used as the parameters for the database connection.
    def initialize(app_config, adapter, conn_details)
      @app_config = app_config
      @adapter = adapter
      @conn_details = conn_details
      # Digest of the app config file so we can tell if it changes
      @config_md5 = app_config.config_md5
      
      if @conn_details.is_a?(Hash)
        # Add in the adapter name
        @conn_details['adapter'] = adapter unless @conn_details.key?('adapter')
        # Add in default database name if none was specified
        @conn_details['database'] = DB_NAME unless @conn_details.key?('database')
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
      
      first_timestamp = SequelIndexDriver.first_service_execution_timestamp(expected_services, md_rec)
      
      if @adapter == :mysql || @adapter == :mysql2
        # Reformat the date to meet mysql's requirements
        formatted = first_timestamp.nil? ? nil : DateTime.iso8601(first_timestamp).strftime('%Y-%m-%d %H:%M:%S')
        preserve_tbl.on_duplicate_key_update(:service_time)
            .insert(file_path: file_path, service_time: formatted)
      else
        preserve_tbl.insert_conflict(target: :file_path, update: {service_time: first_timestamp})
            .insert(file_path: file_path, service_time: first_timestamp)
      end
    end
    
    # Find the earliest service execution time for any services expected to be run for the specified file.
    #
    # @param expected_services [Array] list of ServiceDefinition objects expected for specified file.
    # @param md_rec [MetadataRecord] metadata record for the file being evaluated
    # @return The timestamp of the earliest service execution time for the file described by md_rec, in iso8601 format.
    #    Returns nil if no services are expected or all services have already run and do not have a next occurrence.
    def self.first_service_execution_timestamp(expected_services, md_rec)
      current_time = Time.now.iso8601
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
    
    # Initialize the index's database using the provided configuration
    def setup_index
      # Create the table for tracking when files will need preservation services run on them.
      db_conn.create_table!(PRESERVE_TBL) do
        String :file_path, primary_key: true, size: 768
        DateTime :service_time, null: true
      end
  
      # Setup database indexes
      case(@adapter)
      when :postgres
        db_conn.run("CREATE INDEX service_times_file_path_text_index ON preserve_service_times (file_path text_pattern_ops)")
      when :sqlite, :amalgalite
        db_conn.run("CREATE INDEX service_times_file_path_text_index ON preserve_service_times (file_path collate nocase)")
      end
      
      # Create table for tracking 
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
      db_conn[INDEX_STATE_TBL].insert(
          config_md5: @config_md5,
          last_reindexed: DateTime.now,
          longleaf_version: Longleaf::VERSION)
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
  end
end