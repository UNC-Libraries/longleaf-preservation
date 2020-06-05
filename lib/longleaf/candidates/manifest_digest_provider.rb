module Longleaf
  # Provides digests for files from a manifest
  class ManifestDigestProvider
    # @param hash which maps file paths to hashs of digests
    def initialize(digests_mapping)
      @digests_mapping = digests_mapping
    end

    # @param file_path [String] path of file
    # @return hash containing all the manifested digests for the given path, or nil
    def get_digests(file_path)
      # return nil if key not found, in case the hash has default values
      return nil unless @digests_mapping.key?(file_path)
      @digests_mapping[file_path]
    end
  end
end
