module Longleaf
  class LongleafError < StandardError; end
  
  class ConfigurationError < LongleafError; end
  
  class InvalidStoragePathError < LongleafError; end
  
  class MetadataError < LongleafError; end
  
  class StorageLocationUnavailableError < LongleafError; end
end