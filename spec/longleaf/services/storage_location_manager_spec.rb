require 'spec_helper'
require 'longleaf/services/storage_location_manager'
require 'longleaf/specs/config_builder'

describe Longleaf::StorageLocationManager do
  ConfigBuilder = Longleaf::ConfigBuilder
  
  describe '.initialize' do
    context 'with empty config' do
      it { expect { build(:storage_location_manager) }.to raise_error(ArgumentError) }
    end
    
    context 'with invalid location' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 'loc1', path: nil).get }
      let(:manager) { build(:storage_location_manager, config: config) }
      
      it { expect { build(:storage_location_manager, config: config) }.to raise_error(ArgumentError) }
    end
  end
  
  describe '.locations' do
    context 'with no locations' do
      let(:config) { ConfigBuilder.new.with_locations.get }
      let(:manager) { build(:storage_location_manager, config: config) }
      
      it { expect(manager.locations).to be_empty }
    end
    
    context 'with valid location' do
      let(:config) { ConfigBuilder.new.with_locations.with_location(name: 's_loc').get }
      let(:manager) { build(:storage_location_manager, config: config) }
      
      it { expect(manager.locations).to_not be_empty }
      it 'returns location s_loc' do
        location = manager.locations['s_loc']
        
        expect(location.name).to eq 's_loc'
        expect(location.path).to eq '/file/path/'
        expect(location.metadata_path).to eq '/metadata/path/'
      end
    end
    
    context 'with multiple locations' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: '/file/path1/', md_path: '/metadata/path1/')
          .with_location(name: 'loc2', path: '/file/path2/', md_path: '/metadata/path2/')
          .get }
      let(:manager) { build(:storage_location_manager, config: config) }
      
      it { expect(manager.locations).to_not be_empty }
      it { expect(manager.locations.length).to eq 2 }
      
      it 'returns location loc1' do
        location = manager.locations['loc1']
        
        expect(location.name).to eq 'loc1'
        expect(location.path).to eq '/file/path1/'
        expect(location.metadata_path).to eq '/metadata/path1/'
      end
      
      it 'returns location loc2' do
        location = manager.locations['loc2']
        
        expect(location.name).to eq 'loc2'
        expect(location.path).to eq '/file/path2/'
        expect(location.metadata_path).to eq '/metadata/path2/'
      end
    end
  end
  
  describe '.get_location_by_path' do
    context 'with no locations' do
      let(:config) { ConfigBuilder.new.with_locations.get }
      let(:manager) { build(:storage_location_manager, config: config) }
      
      it { expect(manager.get_location_by_path('s_loc')).to be_nil }
    end
    
    context 'with multiple locations' do
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: '/file/path1/', md_path: '/metadata/path1/')
          .with_location(name: 'loc2', path: '/file/path2/', md_path: '/metadata/path2/')
          .get }
      let(:manager) { build(:storage_location_manager, config: config) }
      
      it 'raises error when no path provided' do
        expect { manager.get_location_by_path }.to raise_error(ArgumentError)
      end
      
      it 'returns nil for file not in a registered storage location' do
        expect(manager.get_location_by_path('/unknown/loc/file.txt')).to be_nil
      end
      
      it 'returns nil for a file in a parent directory of a storage location' do
        expect(manager.get_location_by_path('/file/file.txt')).to be_nil
      end
      
      it 'returns location for file in loc1' do
        result = manager.get_location_by_path('/file/path1/file.txt')
        
        expect(result.name).to eq 'loc1'
        expect(result.path).to eq '/file/path1/'
      end
      
      it 'returns location for file in loc2' do
        result = manager.get_location_by_path('/file/path2/file.txt')
        
        expect(result.name).to eq 'loc2'
        expect(result.path).to eq '/file/path2/'
      end
    end
  end
end