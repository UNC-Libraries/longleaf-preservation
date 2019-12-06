require 'longleaf/models/storage_location'
require 'longleaf/helpers/s3_uri_helper'
require 'uri'
require 'aws-sdk-s3'

module Longleaf
  # A storage location in a s3 bucket
  #
  # Optionally, the location configuration may include an "options" sub-hash in order to provide
  # any of the s3 client options specified in Client initializer:
  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#constructor_details

  class S3StorageLocation < StorageLocation

    IS_URI_REGEX = /\A#{URI::regexp}\z/

    CLIENT_OPTIONS_FIELD = 'options'

    # @param name [String] the name of this storage location
    # @param config [Hash] hash containing the configuration options for this location
    # @param md_loc [MetadataLocation] metadata location associated with this storage location
    def initialize(name, config, md_loc)
      super(name, config, md_loc)

      @bucket_name = S3UriHelper.extract_bucket(@path)
      if @bucket_name.nil?
        raise ArgumentError.new("Unable to identify bucket for location #{@name} from path #{@path}")
      end

      # Force path to always end with a slash
      @path += '/' unless @path.end_with?('/')

      custom_options = config[CLIENT_OPTIONS_FIELD]
      if custom_options.nil?
        @client_options = Hash.new
      else
        # Clone options and convert keys to symbols
        @client_options = Hash[custom_options.map { |(k,v)| [k.to_sym,v] } ]
      end
      # If no region directly configured, use region from path
      if !@client_options.key?(:region)
        region = S3UriHelper.extract_region(@path)
        @client_options[:region] = region unless region.nil?
      end
    end

    # @return the storage type for this location
    def type
      AppFields::S3_STORAGE_TYPE
    end

    # Get that absolute path to the file associated with the provided metadata path
    # @param md_path [String] metadata file path
    # @raise [ArgumentError] if the md_path is not in this storage location
    # @return [String] the path for the file associated with this metadata
    def get_path_from_metadata_path(md_path)
      raise ArgumentError.new("A file_path parameter is required") if md_path.nil? || md_path.empty?

      rel_path = @metadata_location.relative_file_path_for(md_path)

      URI.join(@path, rel_path).to_s
    end

    # Checks that the path and metadata path defined in this location are available
    # @raise [StorageLocationUnavailableError] if the storage location is not available
    def available?
      begin
        s3_client().head_bucket({ bucket: @bucket_name, use_accelerate_endpoint: false })
      rescue StandardError => e
        raise StorageLocationUnavailableError.new("Destination bucket #{@bucket_name} does not exist " \
            + "or is not accessible: #{e.message}")
      end
      @metadata_location.available?
    end

    # Get the file path relative to this location
    # @param file_path [String] file path
    # @return the file path relative to this location
    # @raise [ArgumentError] if the file path is not contained by this location
    def relativize(file_path)
      raise ArgumentError.new("Must provide a non-nil path to relativize") if file_path.nil?

      if file_path.start_with?(@path)
        file_path[@path.length..-1]
      else
        if file_path =~ IS_URI_REGEX
          raise ArgumentError.new("Path #{file_path} is not contained by #{@name}")
        else
          # path already relative
          file_path
        end
      end
    end

    # @return the bucket used by this storage location
    def s3_bucket
      if @bucket.nil?
        @s3 = Aws::S3::Resource.new(client: s3_client())
        @bucket = @s3.bucket(@bucket_name)
      end
      @bucket
    end

    # @return the s3 client used by this storage locatio
    def s3_client
      if @client.nil?
        @client = Aws::S3::Client.new(**@client_options)
      end
      @client
    end
  end
end
