require 'longleaf/models/system_config_fields'
require 'longleaf/services/metadata_persistence_manager'
require 'longleaf/errors'

module Longleaf
  # Manager configures and provides access to a metadata index if one is specified
  class IndexManager
    SYS_FIELDS ||= Longleaf::SystemConfigFields

    # @param config [Hash] The system configuration as a hash
    # @param app_config_manager [ApplicationConfigManager] the application config
    def initialize(config, app_config_manager)
      @config = config
      @app_config_manager = app_config_manager
      init_index_driver if @config&.key?(SYS_FIELDS::MD_INDEX)
    end

    # @return true if the system is configured to use a metadata index
    def using_index?
      !@index_driver.nil?
    end

    # Index the provided file_rec and its metadata
    #
    # @param file_rec [FileRecord] file record to index
    def index(file_rec)
      @index_driver.index(file_rec)
    end

    # Remove an entry from the index
    # @param remove_me The record to remove from the index
    def remove(remove_me)
      @index_driver.remove(remove_me)
    end

    def clear_index(older_than = nil)
      @index_driver.clear_index(older_than)
    end

    # @return true if the index should be reindexed
    def index_stale?
      @index_driver.is_stale?
    end

    # Setup initial structure of index implementation
    def setup_index
      @index_driver.setup_index
    end

    def update_index_state
      @index_driver.update_index_state
    end

    # Retrieves a set of which have one or more services which need to run.
    #
    # @param file_selector [FileSelector] selector for paths to search for files
    # @param stale_datetime [DateTime] find file_paths with services needing to be run before this value
    # @return [Array] array of file paths that need one or more services run, in ascending order by
    #    timestamp.
    def paths_with_stale_services(file_selector, stale_datetime)
      @index_driver.paths_with_stale_services(file_selector, stale_datetime)
    end

    # Retrieves a page of paths for registered files.
    # @param file_selector [FileSelector] selector for what paths to search for files
    # @return [Array] array of file paths that are registered
    def registered_paths(file_selector)
      @index_driver.registered_paths(file_selector)
    end

    def each_registered_path(file_selector, older_than: nil, &block)
      @index_driver.each_registered_path(file_selector, older_than: older_than, &block)
    end

    private
    def init_index_driver
      index_conf = @config[SYS_FIELDS::MD_INDEX]
      adapter = index_conf[SYS_FIELDS::MD_INDEX_ADAPTER]&.downcase

      raise ConfigurationError.new('Must specify an adapter for the metadata index') if adapter.nil?

      adapter = adapter.to_sym

      case adapter
      when :postgres, :mysql, :mysql2, :sqlite, :amalgalite
        page_size = index_conf[SYS_FIELDS::MD_INDEX_PAGE_SIZE]&.to_int

        connection = index_conf[SYS_FIELDS::MD_INDEX_CONNECTION]
        raise ConfigurationError.new("Must specify connection details for index adapter of type '#{adapter}'") if connection.nil?

        require 'longleaf/indexing/sequel_index_driver'
        @index_driver = SequelIndexDriver.new(@app_config_manager,
            adapter,
            connection,
            page_size: page_size)
      else
        raise ConfigurationError.new("Unknown index adapter '#{adapter}' specified.") if adapter.nil?
      end
    end
  end
end
