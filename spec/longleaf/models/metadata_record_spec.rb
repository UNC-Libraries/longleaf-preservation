require 'spec_helper'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'

describe Longleaf::MetadataRecord do
  MDF ||= Longleaf::MDFields
  
  describe '.properties' do
    context 'with no properties' do
      let(:record) { build(:metadata_record) }
      
      it { expect(record.properties).to be_empty }
    end
    
    context 'with properties' do
      let(:basic_properties) {
        {
          MDF::FILE_SIZE => 1500,
          'extra_property' => 'value'
        }
      }
      let(:record)  { build(:metadata_record, properties: basic_properties) }
      
      it { expect(record.properties).to include(basic_properties) }
      it { expect(record.properties.length).to eq 2 }
    end
  end
  
  describe '.checksums' do
    context 'with no properties' do
      let(:record) { build(:metadata_record) }
      
      it { expect(record.checksums).to be_empty }
      
      it 'adds a checksum' do
        record.checksums['MD5'] = 'digest'
        
        expect(record.checksums).to include('MD5' => 'digest')
      end
      
      it 'removes a checksum' do
        record.checksums.delete('MD5')
        
        expect(record.checksums).to be_empty
      end
    end
    
    context 'with checksum properties' do
      let(:expected_checksums) { {'SHA1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83' } }
      let(:record) { build(:metadata_record, checksums: expected_checksums ) }
      
      it { expect(record.checksums).to include(expected_checksums) }
      it { expect(record.checksums.length).to eq 1 }
    end
  end
  
  describe '.registered' do
    context 'with no properties' do
      let(:record) { build(:metadata_record) }
      
      it { expect(record.registered).to be_nil }
    end

    context 'with property' do
      let(:record) { build(:metadata_record, registered: '2018-01-01T00:00:00.000Z') }
      
      it { expect(record.registered).to eq '2018-01-01T00:00:00.000Z' }
    end
  end
  
  describe '.deregistered' do
    context 'with no properties' do
      let(:record) { build(:metadata_record) }
      
      it { expect(record.deregistered).to be_nil }
      it { expect(record.deregistered?).to be false }
    end
    
    context 'with deregistered property' do
      let(:record) { build(:metadata_record, deregistered: '2018-01-01T00:00:00.000Z') }
      
      it { expect(record.deregistered).to eq '2018-01-01T00:00:00.000Z' }
      it { expect(record.deregistered?).to be true }
    end
  end
  
  describe '.list_services' do
    context 'with no services' do
      let(:record) { build(:metadata_record) }
      
      it { expect(record.list_services).to be_empty }
    end
    
    context 'with services' do
      let(:record) { build(:metadata_record, :multiple_services) }
      
      it { expect(record.list_services).to include(:service_1, :service_2) }
      it { expect(record.list_services.length).to eq 2 }
    end
  end
  
  describe '.service' do
    context 'with services' do
      let(:record) { build(:metadata_record, :multiple_services) }
      
      let(:service_1) { record.service(:service_1)  }
      it 'contains service_1' do
        expect(service_1).to_not be_nil
        expect(service_1.timestamp).to eq '2018-01-01T01:00:00.000Z'
      end
      
      let(:service_2) { record.service(:service_2)  }
      it 'contains service_2' do
        expect(service_2).to_not be_nil
        expect(service_2.timestamp).to eq '2018-01-01T02:00:00.000Z'
        expect(service_2['service_prop']).to eq 'value'
      end
      
      it 'does not contain other services' do
        expect(record.service('other_service')).to be_nil
      end
    end
  end
  
  describe '.add_service' do
    let(:record) { build(:metadata_record) }
    
    it 'includes empty service' do
      created_service = record.add_service('new_service')
      
      expect(created_service.properties).to be_empty
      expect(record.service('new_service').properties).to be_empty
    end
  
    it 'adds service with properties' do
      service_rec = build(:service_record, timestamp: '2018-01-01T01:00:00.000Z') 
      created_service = record.add_service('new_service_2', service_rec)
      
      expect(created_service).to be record.service('new_service_2')
      expect(record.service('new_service_2').timestamp).to eq ('2018-01-01T01:00:00.000Z')
    end
    
    it 'rejects non-hash service properties' do
      expect { record.add_service('bad_service', 'value') }.to raise_error(ArgumentError)
    end
  end
end
