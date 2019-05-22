require 'longleaf/errors'

module Longleaf
  # Validator for storage paths
  class StoragePathValidator
    # Checks that the given path is a syntactically valid storage path
    # @param path [String] file storage path to validate
    # @raise [InvalidStoragePathError]
    def self.validate(path)
      raise InvalidStoragePathError.new("Path must not be empty") if path.to_s.strip.empty?
      raise InvalidStoragePathError.new("Path must be absolute") unless Pathname.new(path).absolute?
      raise InvalidStoragePathError.new("Path must not contain any relative modifiers (/..)") \
          if path.include?('/..')
    end
  end
end
