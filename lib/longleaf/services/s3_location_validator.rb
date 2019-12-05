require 'pathname'
require 'longleaf/errors'
require 'longleaf/helpers/s3_uri_helper'

module Longleaf
  # Validates the configuration of a s3 based location
  class S3LocationValidator
    def self.validate(p_validator, name, path_prop, section_name, path)
      base_msg = "Storage location '#{name}' specifies invalid #{section_name} '#{path_prop}' property: "
      p_validator.assert(base_msg + 'Path must not be empty', !path.nil? && !path.to_s.strip.empty?)
      begin
        bucket_name = S3UriHelper.extract_bucket(path)
        p_validator.assert(base_msg + 'Path must specify a bucket', !bucket_name.nil?)
      rescue ArgumentError => e
        p_validator.fail(base_msg + e.message)
      end
    end
  end
end
