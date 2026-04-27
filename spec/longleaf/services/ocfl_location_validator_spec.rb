require 'spec_helper'
require 'fileutils'
require 'longleaf/services/ocfl_location_validator'
require 'longleaf/services/configuration_validator'
require 'longleaf/errors'

describe Longleaf::OcflLocationValidator do
  let(:p_validator) { Longleaf::ConfigurationValidator.new(nil) }
  let(:validator) { Longleaf::OcflLocationValidator }

  describe '#validate' do
    it 'rejects a nil path' do
      expect { validator.validate(p_validator, 'loc1', 'path', 'location', nil) }
        .to raise_error(Longleaf::ConfigurationError, /Path must not be empty/)
    end

    it 'rejects an empty path' do
      expect { validator.validate(p_validator, 'loc1', 'path', 'location', ' ') }
        .to raise_error(Longleaf::ConfigurationError, /Path must not be empty/)
    end

    it 'rejects a relative path' do
      expect { validator.validate(p_validator, 'loc1', 'path', 'location', 'relative/path/') }
        .to raise_error(Longleaf::ConfigurationError, /Path must be absolute/)
    end

    it 'rejects a path with relative modifiers' do
      expect { validator.validate(p_validator, 'loc1', 'path', 'location', '/path/to/../ocfl/') }
        .to raise_error(Longleaf::ConfigurationError, /Path must not contain any relative modifiers/)
    end

    it 'rejects a path that does not exist' do
      expect { validator.validate(p_validator, 'loc1', 'path', 'location', '/nonexistent/path/') }
        .to raise_error(Longleaf::ConfigurationError, /Path does not exist/)
    end

    context 'with an existing directory' do
      let(:path_dir) { Dir.mktmpdir('ocfl-root') }

      after { FileUtils.remove_dir(path_dir) }

      it 'rejects a directory with no namaste file' do
        expect { validator.validate(p_validator, 'loc1', 'path', 'location', path_dir) }
          .to raise_error(Longleaf::ConfigurationError, /does not contain an OCFL namaste file/)
      end

      it 'accepts a directory with an OCFL 1.1 namaste file' do
        FileUtils.touch(File.join(path_dir, '0=ocfl_1.1'))
        expect { validator.validate(p_validator, 'loc1', 'path', 'location', path_dir) }
          .not_to raise_error
      end

      it 'accepts a directory with an OCFL 1.0 namaste file' do
        FileUtils.touch(File.join(path_dir, '0=ocfl_1.0'))
        expect { validator.validate(p_validator, 'loc1', 'path', 'location', path_dir) }
          .not_to raise_error
      end

      it 'rejects a directory with only an object namaste file (not a storage root)' do
        FileUtils.touch(File.join(path_dir, '0=ocfl_object_1.1'))
        expect { validator.validate(p_validator, 'loc1', 'path', 'location', path_dir) }
          .to raise_error(Longleaf::ConfigurationError, /does not contain an OCFL namaste file/)
      end
    end

    context 'using the spec fixture OCFL root' do
      let(:fixture_path) { File.expand_path('../../fixtures/ocfl-root', __dir__) }

      it 'accepts the fixture as a valid OCFL storage root' do
        expect { validator.validate(p_validator, 'loc1', 'path', 'location', fixture_path) }
          .not_to raise_error
      end
    end
  end
end
