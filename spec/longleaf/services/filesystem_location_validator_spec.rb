require 'spec_helper'
require 'fileutils'
require 'longleaf/services/filesystem_location_validator'
require 'longleaf/services/configuration_validator'
require 'longleaf/errors'

describe Longleaf::FilesystemLocationValidator do
  let(:p_validator) { Longleaf::ConfigurationValidator.new(nil) }
  let(:validator) { Longleaf::FilesystemLocationValidator }

  describe '#validate' do
    it 'rejects a nil path' do
      expect { validator::validate(p_validator, 'loc1', 'path', 'location', nil) }.to raise_error(Longleaf::ConfigurationError,
          /Path must not be empty/)
    end

    it 'rejects an empty path' do
      expect { validator::validate(p_validator, 'loc1', 'path', 'location', ' ') }.to raise_error(Longleaf::ConfigurationError,
          /Path must not be empty/)
    end

    it 'rejects a relative path' do
      expect { validator::validate(p_validator, 'loc1', 'path', 'location', 'relative/path/file.txt') }.to raise_error(Longleaf::ConfigurationError,
          /Path must be absolute/)
    end

    it 'rejects a path with modifiers' do
      expect { validator::validate(p_validator, 'loc1', 'path', 'location', '/path/to/../file.txt') }.to raise_error(Longleaf::ConfigurationError,
          /Path must not contain any relative modifiers/)
    end

    context 'path does not exist' do
      it 'passes an absolute path' do
        expect { validator::validate(p_validator, 'loc1', 'path', 'location', '/path/to/file') }.to raise_error(Longleaf::ConfigurationError,
            /Path does not exist/)
      end
    end

    context 'path exists' do
      let(:path_dir1) { Dir.mktmpdir('path') }
      after do
        FileUtils.rm_rf([path_dir1])
      end

      it 'passes an absolute path' do
        expect { validator::validate(p_validator, 'loc1', 'path', 'location', path_dir1) }.to_not raise_error
      end
    end
  end
end
