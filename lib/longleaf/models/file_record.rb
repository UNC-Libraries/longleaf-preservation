module Longleaf
  # Record for an individual file and its associated information
  class FileRecord
    
    attr_accessor :metadata_record
    attr_reader :storage_location
    attr_reader :path
    
    # @param file_path [String] path to the file
    # @param storage_location [StorageLocation] storage location containing the file
    def initialize(file_path, storage_location, metadata_record = nil)
      raise ArgumentError.new("FileRecord requires a path") if file_path.nil?
      raise ArgumentError.new("FileRecord requires a storage_location") if storage_location.nil?
      
      @path = file_path
      @storage_location = storage_location
      @metadata_record = metadata_record
    end
    
    # @return [String] path for the metadata file for this file
    def metadata_path
      @metadata_path = @storage_location.get_metadata_path_for(path) if @metadata_path.nil?
      @metadata_path
    end
    
    def registered?
      File.exist?(metadata_path)
    end
  end
end