require 'spec_helper'
require 'fileutils'
require 'longleaf/services/s3_location_validator'
require 'longleaf/services/configuration_validator'
require 'longleaf/errors'

describe Longleaf::S3LocationValidator do
  let(:p_validator) { Longleaf::ConfigurationValidator.new(nil) }
  let(:validator) { Longleaf::S3LocationValidator }

  describe '#validate' do
    it 'rejects a nil path' do
      expect { validator::validate(p_validator, 'loc1', 'path', 'location', nil) }.to raise_error(Longleaf::ConfigurationError,
          /Path must not be empty/)
    end

    it 'rejects an empty path' do
      expect { validator::validate(p_validator, 'loc1', 'path', 'location', ' ') }.to raise_error(Longleaf::ConfigurationError,
          /Path must not be empty/)
    end

    it 'rejects path with unacceptable scheme' do
      expect { validator::validate(p_validator, 'loc1', 'path', 'location', 'file://path/to/stuff') }.to raise_error(Longleaf::ConfigurationError,
          /Invalid scheme for s3 URI/)
    end

    it 'rejects path without hostname' do
      expect { validator::validate(p_validator, 'loc1', 'path', 'location', 'http:///path/to/stuff') }.to raise_error(Longleaf::ConfigurationError,
          /Invalid S3 URI, no hostname/)
    end

    it 'rejects path without a bucket' do
      expect { validator::validate(p_validator, 'loc1', 'path', 'location', 'http://s3.example.com/') }.to raise_error(Longleaf::ConfigurationError,
          /Path must specify a bucket/)
    end

    it 'passes a valid s3 uri' do
      expect { validator::validate(p_validator, 'loc1', 'path', 'location', 'http://mybucket.s3-example.com/') }.to_not raise_error
    end
  end
end
