module Longleaf
  class LongleafError < StandardError; end
  
  class ConfigurationError < LongleafError; end
  
  class InvalidStoragePathError < LongleafError; end
  
  class MetadataError < LongleafError; end
  
  class StorageLocationUnavailableError < LongleafError; end
  
  class EventError < LongleafError; end
  
  class RegistrationError < EventError; end
  
  class PreservationServiceError < LongleafError; end
  
  class ChecksumMismatchError < PreservationServiceError; end
end