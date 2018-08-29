require 'spec_helper'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'

describe Longleaf::MetadataRecord do
  MDF = Longleaf::MDFields
  
  let(:record_no_props) {
    Longleaf::MetadataRecord.new
  }
  
  let(:record_with_props) {
    Longleaf::MetadataRecord.new({
      MDF::REGISTERED_TIMESTAMP => '2018-01-01T00:00:00.000Z',
      MDF::FILE_SIZE => 1500,
      'extra_property' => 'value',
      MDF::CHECKSUMS => { 'SHA1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83' }
    })
  }
  
  let(:record_with_services) {
    Longleaf::MetadataRecord.new({
      MDF::REGISTERED_TIMESTAMP => '2018-01-01T00:00:00.000Z'
    }, { 
      'service_1' => {
        MDF::SERVICE_TIMESTAMP => '2018-01-01T01:00:00.000Z'
      },
      'service_2' => {
        MDF::SERVICE_TIMESTAMP => '2018-01-01T02:00:00.000Z',
        'service_prop' => 'value'
      },  
    })
  }
  
  describe '.properties' do
    context 'with no properties' do
      it { expect(record_no_props.properties).to be_empty }
    end
    
    context 'with properties' do
      subject { record_with_props.properties }
      
      it { is_expected.to include(MDF::FILE_SIZE => 1500,
        'extra_property' => 'value') }
      it { expect(subject.length).to eq 2 }
    end
  end
  
  describe '.checksums' do
    context 'with no properties' do
      subject { record_no_props.checksums }
      
      it { is_expected.to be_empty }
      it 'adds a checksum' do
        subject['MD5'] = 'digest'
        
        is_expected.to include('MD5' => 'digest')
      end
      it 'removes a checksum' do
        subject.delete('MD5')
        
        is_expected.to be_empty
      end
    end
    
    context 'with checksum properties' do
      subject { record_with_props.checksums }
      
      it { is_expected.to include('SHA1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83') }
      it { expect(subject.length).to eq 1 }
    end
  end
  
  describe '.registered' do
    context 'with no properties' do
      it { expect(record_no_props.registered).to be_nil }
    end

    context 'with properties' do
      it { expect(record_with_props.registered).to eq '2018-01-01T00:00:00.000Z' }
    end
  end
  
  describe '.deregistered' do
    context 'with no properties' do
      it { expect(record_no_props.deregistered).to be_nil }
      it { expect(record_no_props.deregistered?).to be false }
    end
    
    context 'with deregistered property' do
      subject {
        Longleaf::MetadataRecord.new({
          MDF::DEREGISTERED_TIMESTAMP => '2018-01-01T00:00:00.000Z'
        })
      }
      
      it { expect(subject.deregistered).to eq '2018-01-01T00:00:00.000Z' }
      it { expect(subject.deregistered?).to be true }
    end
  end
  
  describe '.list_services' do
    context 'with no services' do
      it { expect(subject.list_services).to be_empty }
    end
    
    context 'with services' do
      subject { record_with_services.list_services }
      
      it { is_expected.to include('service_1', 'service_2') }
      it { expect(subject.length).to eq 2 }
    end
  end
  
  describe '.service' do
    context 'with services' do
      subject { record_with_services }
      
      let(:service_1) { subject.service('service_1')  }
      it 'contains service_1' do
        expect(service_1).to_not be_nil
        expect(service_1.timestamp).to eq '2018-01-01T01:00:00.000Z'
      end
      
      let(:service_2) { subject.service('service_2')  }
      it 'contains service_2' do
        expect(service_2).to_not be_nil
        expect(service_2.timestamp).to eq '2018-01-01T02:00:00.000Z'
        expect(service_2['service_prop']).to eq 'value'
      end
      
      it 'does not contain other services' do
        expect(record_with_services.service('other_service')).to be_nil
      end
    end
  end
  
  describe '.add_service' do
    subject { record_no_props }
    
    it 'includes empty service' do
      created_service = subject.add_service('new_service')
      
      expect(created_service.properties).to be_empty
      expect(subject.service('new_service').properties).to be_empty
    end
  
    it 'adds service with properties' do
      created_service = subject.add_service('new_service_2', { MDF::SERVICE_TIMESTAMP => '2018-01-01T01:00:00.000Z' })
      
      expect(created_service).to_not be_nil
      expect(created_service.timestamp).to eq ('2018-01-01T01:00:00.000Z')
      expect(subject.service('new_service_2').timestamp).to eq ('2018-01-01T01:00:00.000Z')
    end
    
    it 'rejects non-hash service properties' do
      expect { subject.add_service('bad_service', 'value') }.to raise_error(ArgumentError)
    end
  end
end
