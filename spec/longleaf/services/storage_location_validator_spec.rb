require 'spec_helper'
require 'longleaf/services/storage_location_validator'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'

describe Longleaf::StorageLocationValidator do
  Validator = Longleaf::StorageLocationValidator
  AF = Longleaf::AppFields
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
  describe '#validate_config' do
    
    context 'with non-hash config' do
      it { expect { Validator::validate_config('bad') }.to raise_error(Longleaf::ConfigurationError, /must be a hash/) }
    end
    
    context 'with no locations field' do
      it { expect { Validator::validate_config({}) }.to raise_error(Longleaf::ConfigurationError, /must contain a root/) }
    end
    
    context 'with invalid locations value' do
      let(:config) { ConfigBuilder.new.with_locations('bad').get }
      
      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError, /must be a hash of locations/) }
    end
    
    context 'with empty locations' do
      let(:config) { ConfigBuilder.new.with_locations.get }
      
      it { expect { Validator::validate_config(config) }.to_not raise_error }
    end
    
    context 'with location missing path' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 'loc1', path: nil).get }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /must specify a 'path'/) }
    end
    
    context 'with location missing metadata path' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 'loc1', md_path: nil).get }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /must specify a 'metadata_path'/) }
    end
    
    context 'with location with non-absolute path' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 'loc1', path: 'path/').get }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /an absolute path for proprety 'path'/) }
    end
    
    context 'with location with path modifiers' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 'loc1', path: '/file/../path/').get }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /an absolute path for proprety 'path'/) }
    end
    
    context 'with location with non-absolute metadata_path' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 'loc1', md_path: 'md_path/').get }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /an absolute path for proprety 'metadata_path'/) }
    end
    
    context 'with location with non-hash location' do
      let(:config) { ConfigBuilder.new.with_locations.get }
      before { config[AF::LOCATIONS]['loc1'] = 'bad' }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /location 'loc1' must be a hash/) }
    end
    
    context 'with location path contained by metadata_path' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: '/file/path/', md_path: '/file/path/')
          .get }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /overlaps with another configured path/) }
    end
    
    context 'with location path contained by another location path' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: '/path/loc1/', md_path: '/md/loc1/')
          .with_location(name: 'loc2', path: '/path/loc1/loc2', md_path: '/md/loc2/')
          .get }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /overlaps with another configured path/) }
    end
    
    context 'with location path contained by another location path without trailing slash' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: '/path/loc1', md_path: '/md/loc1/')
          .with_location(name: 'loc2', path: '/path/loc1/loc2', md_path: '/md/loc2/')
          .get }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /overlaps with another configured path/) }
    end
    
    # Ensuring problem is caught in either direction
    context 'with location path containing by another location path' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: '/path/loc2/loc1', md_path: '/md/loc1/')
          .with_location(name: 'loc2', path: '/path/loc2/', md_path: '/md/loc2/')
          .get }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /overlaps with another configured path/) }
    end
    
    context 'with location path contained by another location metadata_path' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: '/path/loc1/', md_path: '/md/loc1/')
          .with_location(name: 'loc2', path: '/md/loc1/loc2', md_path: '/md/loc2/')
          .get }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /overlaps with another configured path/) }
    end
    
    context 'location with invalid name' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: { 'random' => 'stuff' } ).get }

      it { expect { Validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /Name of storage location must be a string/) }
    end
    
    context 'with valid location' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1').get }

      it { expect { Validator::validate_config(config) }.to_not raise_error }
    end
    
    context 'with multiple valid locations' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: '/path/loc1/', md_path: '/md/loc1/')
          .with_location(name: 'loc2', path: '/path/loc2/', md_path: '/md/loc2/')
          .get }

      it { expect { Validator::validate_config(config) }.to_not raise_error }
    end
  end
end