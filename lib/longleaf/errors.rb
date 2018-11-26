module Longleaf
  # General Longleaf error
  class LongleafError < StandardError; end
  
  # Invalid application configuration error
  class ConfigurationError < LongleafError; end
  
  # Invalid storage path error
  class InvalidStoragePathError < LongleafError; end
  
  # Metadata does not meet requirements error
  class MetadataError < LongleafError; end
  
  # Unavailable storage location error
  class StorageLocationUnavailableError < LongleafError; end
  
  # Error related to executing a preservation event
  class EventError < LongleafError; end
  
  # Error while attempting to perform a registration event
  class RegistrationError < EventError; end
  
  # Error while performing a preservation service
  class PreservationServiceError < LongleafError; end
  
  # Fixity check failure error
  class ChecksumMismatchError < PreservationServiceError; end
end