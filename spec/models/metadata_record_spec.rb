require 'spec_helper'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'

RSpec.describe Longleaf::MetadataRecord do

  context 'given no properties' do
    let(:record) {
      Longleaf::MetadataRecord.new()
    }
    
    it 'should contain no properties or services' do 
      
      expect(record.properties).to be_empty
      expect(record.list_services).to be_empty
      expect(record.checksums).to be_empty
      expect(record.registered).to be_nil
    end
    
    it 'should not be deregistered' do
      expect(record.deregistered?).to eq false
    end
  end
  
  context 'given properties' do
    let(:record) {
      Longleaf::MetadataRecord.new({
        Longleaf::MDFields::REGISTERED_TIMESTAMP => '2018-01-01T00:00:00.000Z',
        Longleaf::MDFields::FILE_SIZE => 1500,
        'extra_property' => 'value',
        Longleaf::MDFields::CHECKSUMS => { 'SHA1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83' }
      })
    }
    
    it 'should contain properties' do 
      expect(record.properties).to include(Longleaf::MDFields::FILE_SIZE => 1500,
        'extra_property' => 'value')
      expect(record.checksums).to include('SHA1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83')
      expect(record.registered).to eq '2018-01-01T00:00:00.000Z'
    end
    
    it 'should not contain services' do
      expect(record.list_services).to be_empty
    end
  end
  
  context 'given services' do
    let(:record) {
      Longleaf::MetadataRecord.new({
        Longleaf::MDFields::REGISTERED_TIMESTAMP => '2018-01-01T00:00:00.000Z'
      }, { 
        'service_1' => {
          Longleaf::MDFields::SERVICE_TIMESTAMP => '2018-01-01T01:00:00.000Z'
        },
        'service_2' => {
          Longleaf::MDFields::SERVICE_TIMESTAMP => '2018-01-01T02:00:00.000Z',
          'service_prop' => 'value'
        },  
      })
    }
    
    it 'should contain registered property' do 
      expect(record.properties).to be_empty
      expect(record.checksums).to be_empty
      expect(record.registered).to eq '2018-01-01T00:00:00.000Z'
    end
    
    it 'should contain provided services' do
      expect(record.list_services).to include('service_1', 'service_2')
      expect(record.service('service_1').timestamp).to eq '2018-01-01T01:00:00.000Z'
      
      expect(record.service('service_2').timestamp).to eq '2018-01-01T02:00:00.000Z'
      expect(record.service('service_2')['service_prop']).to eq 'value'
    end
  end
  
  context 'given a deregistered file' do
    it 'should be deregistered' do
      
    end
  end
  
  context 'add a service' do
    
    it 'should include empty service' do
      
    end
    
    it 'should allow adding properties' do
      
    end
  end
  
  context 'change checksums' do
    it 'should add a checksum' do
      
    end
    
    it 'should remove a checksum' do
      
    end
  end
end