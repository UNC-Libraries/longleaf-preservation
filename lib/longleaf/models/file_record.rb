# Record for an individual file, containing 
module Longleaf
  class FileRecord
    
    attr_accessor :metadata_record
    attr_reader :storage_location
    attr_reader :path
    
    # @param file_path [String] path to the file
    # @param storage_location [Longleaf::StorageLocation] storage location containing the file
    def initialize(file_path, storage_location)
      raise ArgumentError.new("FileRecord requires a path") if file_path.nil?
      raise ArgumentError.new("FileRecord requires a storage_location") if storage_location.nil?
      
      @path = file_path
      @storage_location = storage_location
    end
    
    def metadata_path
      @storage_location.get_metadata_path_for(path)
    end
  end
end