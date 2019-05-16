require 'spec_helper'
require 'longleaf/specs/file_helpers'
require 'longleaf/services/storage_location_validator'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'
require 'fileutils'

describe Longleaf::StorageLocationValidator do
  include Longleaf::FileHelpers
  AF ||= Longleaf::AppFields
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
  let(:validator) { Longleaf::StorageLocationValidator }
  
  let(:path_dir1) { Dir.mktmpdir('path') }
  let(:md_dir1) { Dir.mktmpdir('metadata') }
  
  after do
    FileUtils.rm_rf([md_dir1, path_dir1])
  end
  
  describe '#validate_config' do
    
    context 'with non-hash config' do
      it { expect { validator::validate_config('bad') }.to raise_error(Longleaf::ConfigurationError, /must be a hash/) }
    end
    
    context 'with no locations field' do
      it { expect { validator::validate_config({}) }.to raise_error(Longleaf::ConfigurationError, /must contain a root/) }
    end
    
    context 'with invalid locations value' do
      let(:config) { ConfigBuilder.new.with_locations('bad').get }
      
      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError, /must be a hash of locations/) }
    end
    
    context 'with empty locations' do
      let(:config) { ConfigBuilder.new.with_locations.get }
      
      it { expect { validator::validate_config(config) }.to_not raise_error }
    end
    
    context 'with location missing path' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 'loc1', path: nil, md_path: md_dir1).get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /'path' property: Path must not be empty/) }
    end
    
    context 'with location missing metadata path' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 'loc1', path: path_dir1, md_path: nil).get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /'metadata_path' property: Path must not be empty/) }
    end
    
    context 'with location with non-absolute path' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 'loc1', path: 'path/').get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /'path' property: Path must be absolute/) }
    end
    
    context 'with location with path modifiers' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 'loc1', path: '/file/../path/').get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /'path' property: Path must not contain any relative modifiers/) }
    end
    
    context 'with location with non-absolute metadata_path' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 'loc1', path: path_dir1, md_path: 'md_path/').get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /'metadata_path' property: Path must be absolute/) }
    end
    
    context 'with location with non-hash location' do
      let(:config) { ConfigBuilder.new.with_locations.get }
      before { config[AF::LOCATIONS]['loc1'] = 'bad' }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /location 'loc1' must be a hash/) }
    end
    
    context 'with location path contained by metadata_path' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: path_dir1, md_path: path_dir1)
          .get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /overlaps with another configured path/) }
    end
    
    context 'with location path contained by another location path' do
      let(:path_dir2) { make_test_dir(parent: path_dir1, name: 'loc2') + '/' }
      let(:md_dir2) { make_test_dir(name: 'md_loc2')  + '/' }
      
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
          .with_location(name: 'loc2', path: path_dir2, md_path: md_dir2)
          .get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /overlaps with another configured path/) }
    end
    
    context 'with location path contained by another location path without trailing slash' do
      let(:path_dir2) { make_test_dir(parent: path_dir1, name: 'loc2')}
      let(:md_dir2) { make_test_dir(name: 'md_loc2') }
      
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
          .with_location(name: 'loc2', path: path_dir2, md_path: md_dir2)
          .get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /overlaps with another configured path/) }
    end
    
    # Ensuring problem is caught in either direction
    context 'with location path contained by another location path' do
      let(:path_dir2) { make_test_dir(parent: path_dir1, name: 'loc2')}
      let(:md_dir2) { make_test_dir(name: 'md_loc2') }
      
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: path_dir2, md_path: md_dir2)
          .with_location(name: 'loc2', path: path_dir1, md_path: md_dir1)
          .get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /overlaps with another configured path/) }
    end
    
    context 'with location path contained by another location metadata_path' do
      let(:path_dir2) { make_test_dir(name: 'loc2')}
      let(:md_dir2) { make_test_dir(parent: md_dir1, name: 'md_loc2') }
      
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
          .with_location(name: 'loc2', path: path_dir2, md_path: md_dir2)
          .get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /overlaps with another configured path/) }
    end
    
    context 'location with invalid name' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: { 'random' => 'stuff' } ).get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /Name of storage location must be a string/) }
    end
    
    context 'with valid location' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1).get }

      it { expect { validator::validate_config(config) }.to_not raise_error }
    end
    
    context 'with multiple valid locations' do
      let(:path_dir2) { make_test_dir(name: 'loc2')}
      let(:md_dir2) { make_test_dir(name: 'md_loc2') }
      
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
          .with_location(name: 'loc2', path: path_dir2, md_path: md_dir2)
          .get }

      it { expect { validator::validate_config(config) }.to_not raise_error }
    end
    
    context 'with path that does not exist' do
      before do
        FileUtils.rm_rf(path_dir1)
      end
      
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1).get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError, /Storage location 'loc1' specifies a 'path' directory which does not exist/) }
    end
    
    context 'with metadata path that does not exist' do
      before do
        FileUtils.rm_rf(md_dir1)
      end
      
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1).get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError, /Storage location 'loc1' specifies a 'metadata_path' directory which does not exist/) }
    end
  end
end