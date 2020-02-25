require 'uri'

module Longleaf
  # Helper for interacting with s3 uris
  class S3UriHelper
    ENDPOINT_PATTERN = /^(.+\.)?s3[.\-]([a-z0-9\-]+[\-.])?[a-z0-9]+\./
    ALLOWED_SCHEMES = ['http', 'https', 's3']

    # Extract the name of the s3 bucket from the provided url
    # @param url s3 url
    # @return the name of the bucket, or nil if the name could not be identified
    def self.extract_bucket(url)
      uri = s3_uri(url)

      matches = ENDPOINT_PATTERN.match(uri.host)
      if matches.nil?
        raise ArgumentError.new("Provided URI does match the expected pattern for an S3 URI")
      end

      prefix = matches[1]
      if prefix.nil? || prefix.empty?
        # Is a path style url
        path = uri.path

        return nil if path == '/'

        path_parts = path.split('/')
        return nil if path_parts.empty?
        return path_parts[1]
      else
        return prefix[0..-2]
      end
    end
    
    def self.extract_path(url)
      uri = s3_uri(url)

      matches = ENDPOINT_PATTERN.match(uri.host)
      if matches.nil?
        raise ArgumentError.new("Provided URI does match the expected pattern for an S3 URI")
      end

      path = uri.path
      return nil if path == '/'
      
      # trim off the first slash
      path = path.partition('/').last
      
      # Determine if the first part of the path is the bucket name
      prefix = matches[1]
      if prefix.nil? || prefix.empty?
        # trim off the bucket name
        path = path.partition('/').last
      end
      
      path
    end

    def self.extract_region(url)
      uri = s3_uri(url)

      matches = ENDPOINT_PATTERN.match(uri.host)

      if matches[2].nil?
        # No region specified
        nil
      else
        matches[2][0..-2]
      end
    end

    def self.s3_uri(url)
      if url.nil?
        raise ArgumentError.new("url cannot be empty")
      end
      uri = URI(url)
      if !ALLOWED_SCHEMES.include?(uri.scheme&.downcase)
        raise ArgumentError.new("Invalid scheme for s3 URI #{url}, only http, https and s3 are permitted")
      end
      if uri.host.nil?
        raise ArgumentError.new("Invalid S3 URI, no hostname: #{url}")
      end
      uri
    end
  end
end
