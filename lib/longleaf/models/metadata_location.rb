require 'longleaf/models/app_fields'

module Longleaf
  # A location in which metadata associated with registered files is stored.
  class MetadataLocation
    AF ||= Longleaf::AppFields

    attr_reader :path
    attr_reader :digests

    def initialize(config)
      raise ArgumentError.new("Config parameter is required") unless config
      @path = config[AF::LOCATION_PATH]
      raise ArgumentError.new("Parameter path is required") unless @path
      @path += '/' unless @path.end_with?('/')

      digests = config[AF::METADATA_DIGESTS]
      if digests.nil?
        @digests = []
      elsif digests.is_a?(String)
        @digests = [digests.downcase]
      else
        @digests = digests.map(&:downcase)
      end
      DigestHelper::validate_algorithms(@digests)
    end

    # Transforms the given metadata path into a relative storage location path
    # @param md_path [String] path of the metadata file or directory to compute file path for.
    # @return
    def relative_file_path_for(md_path)
      rel_md_path = relativize(md_path)

      if rel_md_path.end_with?(MetadataSerializer::metadata_suffix)
        rel_md_path[0..-MetadataSerializer::metadata_suffix.length - 1]
      else
        rel_md_path
      end
    end

    # @param [String] metadata path to check
    # @return true if the metadata path is contained by the path for this location
    def contains?(md_path)
      md_path.start_with?(@path)
    end
  end
end
