require 'spec_helper'
require 'longleaf/services/storage_path_validator'
require 'longleaf/errors'

describe Longleaf::StoragePathValidator do
  
  let(:validator) { Longleaf::StoragePathValidator }
  
  describe '#validate' do
    
    it 'rejects a nil path' do
      expect { validator::validate(nil) }.to raise_error(Longleaf::InvalidStoragePathError,
          /Path must not be empty/)
    end
    
    it 'rejects an empty path' do
      expect { validator::validate(' ') }.to raise_error(Longleaf::InvalidStoragePathError,
          /Path must not be empty/)
    end
    
    it 'rejects a relative path' do
      expect { validator::validate('relative/path/file.txt') }.to raise_error(Longleaf::InvalidStoragePathError,
          /Path must be absolute/)
    end
    
    it 'rejects a path with modifiers' do
      expect { validator::validate('/path/to/../file.txt') }.to raise_error(Longleaf::InvalidStoragePathError,
          /Path must not contain any relative modifiers/)
    end
    
    it 'passes an absolute path' do
      expect { validator::validate('/path/to/file.txt') }.to_not raise_error
    end
  end
end