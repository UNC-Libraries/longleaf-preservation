require 'longleaf/models/system_config_fields'
require 'longleaf/services/metadata_persistence_manager'
require 'longleaf/errors'

module Longleaf
  # Manager which configures longleaf system related features, including the metadata index.
  class IndexManager
    SYS_FIELDS ||= Longleaf::SystemConfigFields
    
    def initialize(config, app_config_manager)
      @config = config
      @app_config_manager = app_config_manager
      init_index_driver if @config&.key?(SYS_FIELDS::MD_INDEX)
    end
    
    # @return Returns true if the system is configured to use a metadata index
    def using_index?
      !@index_driver.nil?
    end
    
    # Index the provided file_rec and its metadata
    #
    # @param file_rec [FileRecord] file record to index
    def index(file_rec)
      @index_driver.index(file_rec)
    end
    
    # @return true if the index should be reindexed
    def index_stale?
      @index_driver.is_stale?
    end
    
    # Setup initial structure of index implementation
    def setup_index
      @index_driver.setup_index
    end
    
    private
    def init_index_driver
      index_conf = @config[SYS_FIELDS::MD_INDEX]
      adapter = index_conf[SYS_FIELDS::MD_INDEX_ADAPTER]&.downcase
      
      raise ConfigurationError.new('Must specify an adapter for the metadata index') if adapter.nil?
      
      adapter = adapter.to_sym
      
      case(adapter)
      when :postgres, :mysql, :mysql2, :sqlite, :amalgalite
        connection = index_conf[SYS_FIELDS::MD_INDEX_CONNECTION]
        raise ConfigurationError.new("Must specify connection details for index adapter of type '#{adapter}'") if connection.nil?
        
        require 'longleaf/indexing/sequel_index_driver'
        @index_driver = SequelIndexDriver.new(@app_config_manager, adapter, connection)
      else
        raise ConfigurationError.new("Unknown index adapter '#{adapter}' specified.") if adapter.nil?
      end
    end
  end
end