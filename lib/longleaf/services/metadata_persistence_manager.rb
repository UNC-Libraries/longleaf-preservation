require 'longleaf/services/metadata_serializer'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/errors'

module Longleaf
  # Handles the persistence of metadata records
  class MetadataPersistenceManager
    # Initialize the MetadataPersistenceManager
    # @param index_manager [IndexManager] system config manager
    def initialize(index_manager)
      @index_manager = index_manager
    end

    # Persist the metadata for the provided file record to all configured destinations.
    # This may include to disk as well as to an index.
    # @param file_rec [FileRecord] file record
    def persist(file_rec)
      if file_rec.metadata_record.nil?
        raise MetadataError.new("No metadata record provided, cannot persist metadata for #{file_rec.path}")
      end

      MetadataSerializer::write(metadata: file_rec.metadata_record,
          file_path: file_rec.metadata_path,
          digest_algs: file_rec.storage_location.metadata_location.digests)

      index(file_rec)
    end

    # Index metadata for the provided file record
    # @param file_rec [FileRecord] file record
    def index(file_rec)
      if @index_manager.using_index?
        @index_manager.index(file_rec)
      end
    end

    # Load the metadata record for the provided file record
    # @param file_rec [FileRecord] file record
    # @return [MetadataRecord] the metadata record for the file record
    def load(file_rec)
      md_rec = MetadataDeserializer.deserialize(file_path: file_rec.metadata_path,
                  digest_algs: file_rec.storage_location.metadata_location.digests)
      file_rec.metadata_record = md_rec
      md_rec
    end
  end
end
