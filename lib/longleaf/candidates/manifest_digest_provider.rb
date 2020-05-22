module Longleaf
  # Provides digests for files from a manifest
  class ManifestDigestProvider
    def initialize(path_to_digests)
      @path_to_digests = path_to_digests
    end

    # @param file_path [String] path of file
    # @return hash containing all the manifested digests for the given path, or nil
    def get_digests(file_path)
      # return nil if key not found, in case the hash has default values
      return nil unless @path_to_digests.key?(file_path)
      @path_to_digests[file_path]
    end
  end
end
