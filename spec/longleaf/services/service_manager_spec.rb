require 'spec_helper'
require 'longleaf/services/service_manager'
require 'longleaf/specs/config_builder'
require 'tmpdir'

describe Longleaf::ServiceManager do
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
  describe '.initialize' do
    it 'fails with missing parameters' do
      expect { Longleaf::ServiceManager.new }.to raise_error(ArgumentError)
    end
    
    it 'fails with nil parameters' do
      expect { build(:service_mapping_manager, definition_manager: nil, mapping_manager: nil) }.to raise_error(ArgumentError)
    end
  end
  
  describe '.list_services' do
    context 'with empty sections' do
      let(:config) { ConfigBuilder.new
          .with_services
          .with_locations
          .with_mappings.get }
      let(:manager) { build(:service_manager, config: config) }
      
      it 'returns nothing' do
        expect(manager.list_services(location: 'loc1')).to be_empty
      end
    end
    
    context 'with mappings' do
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:path_dir) { Dir.mktmpdir('path') }
      let(:config) { ConfigBuilder.new
          .with_services
          .with_service(name: 'serv1')
          .with_service(name: 'serv2')
          .with_locations
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', ['serv1', 'serv2'])
          .get }
      let(:manager) { build(:service_manager, config: config) }
      
      after(:each) do
        FileUtils.rmdir([md_dir, path_dir])
      end
      
      it 'returns services for loc1' do
        result = manager.list_services(location: 'loc1')
        expect(result).to contain_exactly('serv1', 'serv2')
      end
      
      it 'returns empty list for unmapped location' do
        expect(manager.list_services(location: 'imaginary_place')).to be_empty
      end
    end
  end
end