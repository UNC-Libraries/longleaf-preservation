require 'longleaf/services/metadata_serializer'

module Longleaf
  # Handles the persistence of metadata records
  class MetadataPersistenceManager
    # Initialize the MetadataPersistenceManager
    # @sys_manager [SystemConfigManager] system config manager
    def initialize(sys_manager)
      @sys_manager = sys_manager
    end
    
    # Persist the metadata for the provided file record to all configured destinations.
    # This may include to disk as well as to an index.
    # @param file_rec [FileRecord] file record
    def persist(file_rec)
      return if file_rec.metadata_record.nil?
      
      MetadataSerializer::write(metadata: file_rec.metadata_record,
          file_path: file_rec.metadata_path,
          digest_algs: file_rec.storage_location.metadata_digests)
      
      index(file_rec)
    end
    
    # Index metadata for the provided file record
    # @param file_rec [FileRecord] file record
    def index(file_rec)
      if @sys_manager.using_index?
        @sys_manager.index_driver.index(file_rec)
      end
    end
  end
end
    