require 'spec_helper'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'
require 'time'

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
    
    it 'rejects duplicate service' do
      record.add_service('new_service')
      expect { record.add_service('new_service') }.to raise_error(IndexError)
    end
  end
  
  describe '.update_service_as_performed' do
    context 'with no run information' do
      let(:record) { build(:metadata_record) }
    
      it 'sets timestamp' do
        record.update_service_as_performed('serv1')
        expect(record.service('serv1').timestamp).to_not be_nil
      end
    end
    
    context 'with run-need' do
      let(:serv_rec) { build(:service_record, run_needed: true)}
      let(:record) { build(:metadata_record, services: { 'serv1' => serv_rec } ) }
      
      it 'sets timestamp and clears run-needed flag' do
        record.update_service_as_performed('serv1')
        expect(record.service('serv1').run_needed).to be false
        expect(record.service('serv1').timestamp).to_not be_nil
      end
    end
    
    context 'metadata record with previous timestamp' do
      let(:past_timestamp) { Longleaf::ServiceDateHelper.formatted_timestamp(Time.now - 1) }
      let(:serv_rec) { build(:service_record, timestamp: past_timestamp)}
      let(:record) { build(:metadata_record, services: { 'serv1' => serv_rec } ) }
      
      it 'replaces timestamp with new timestamp' do
        record.update_service_as_performed('serv1')
        expect(record.service('serv1').timestamp).to_not be_nil
        expect(record.service('serv1').timestamp).to_not eq past_timestamp
      end
    end
  end
  
  describe '.update_service_as_failed' do
    context 'with no run information' do
      let(:record) { build(:metadata_record) }
    
      it 'sets failure timestamp' do
        record.update_service_as_failed('serv1')
        expect(Time.iso8601(record.service('serv1').failure_timestamp)).to be_within(1).of (Time.now)
      end
    end
    
    context 'metadata record with previous timestamp' do
      let(:past_timestamp) { Longleaf::ServiceDateHelper.formatted_timestamp(Time.now - 1) }
      let(:serv_rec) { build(:service_record, timestamp: past_timestamp)}
      let(:record) { build(:metadata_record, services: { 'serv1' => serv_rec } ) }
      
      it 'set failure timestamp and does not affect other details' do
        record.update_service_as_failed('serv1')
        expect(Time.iso8601(record.service('serv1').failure_timestamp)).to be_within(1).of (Time.now)
        expect(record.service('serv1').timestamp).to eq past_timestamp
      end
    end
  end
end
