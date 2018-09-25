require 'spec_helper'
require 'longleaf/services/service_mapping_manager'
require 'longleaf/specs/config_builder'

describe Longleaf::ServiceMappingManager do
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
  describe '.initialize' do
    it 'fails with nil config' do
      expect { build(:service_mapping_manager, config: nil) }.to raise_error(ArgumentError)
    end
    
    it 'fails with no service mappings' do
      expect { build(:service_mapping_manager, config: {}) }.to raise_error(ArgumentError)
    end
  end
  
  describe '.list_services' do
    context 'with no mappings' do
      let(:config) { ConfigBuilder.new.with_mappings.get }
      let(:manager) { build(:service_mapping_manager, config: config) }
      
      it 'returns nothing' do
        expect(manager.list_services('loc1')).to be_empty
      end
    end
    
    context 'with mappings' do
      let(:config) { ConfigBuilder.new
          .map_services('loc1', 'serv1')
          .map_services(['loc2', 'loc3'], ['serv2', 'serv3'])
          .map_services('loc3', 'serv_extra')
          .map_services('loc4', 'serv3')
          .map_services('loc5', ['serv4', 'serv5'])
          .get }
      let(:manager) { build(:service_mapping_manager, config: config) }
      
      it 'returns serv1 for loc1' do
        expect(manager.list_services('loc1')).to contain_exactly('serv1')
      end
      
      # loc2 from multiple location to multiple service mapping
      it 'returns multiple services for loc2' do
        expect(manager.list_services('loc2')).to contain_exactly('serv2', 'serv3')
      end
      
      # loc3 appears in two mappings
      it 'returns merge results for loc3' do
        expect(manager.list_services('loc3')).to contain_exactly('serv2', 'serv3', 'serv_extra')
      end
      
      # serv3 is mapped to multiple locations in separate mappings
      it 'returns only serv3 for loc4' do
        expect(manager.list_services('loc4')).to contain_exactly('serv3')
      end
      
      it 'returns multiple for loc5 in one location to multiple service mapping' do
        expect(manager.list_services('loc5')).to contain_exactly('serv4', 'serv5')
      end
    end
  end
end