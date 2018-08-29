require 'spec_helper'
require 'longleaf/models/service_record'
require 'longleaf/models/md_fields'

describe Longleaf::ServiceRecord do
  MDF = Longleaf::MDFields
  
  let(:record_no_props) {
    Longleaf::ServiceRecord.new
  }
  
  let(:service_props) { {
    MDF::SERVICE_TIMESTAMP => '2018-01-01T01:00:00.000Z',
    MDF::STALE_REPLICAS => true,
    MDF::RUN_NEEDED => true,
    'other_prop' => 'value'
  } }
  
  let(:record_with_props) { Longleaf::ServiceRecord.new(service_props) }
  
  describe '.properties' do
    context 'with no properties' do
      it { expect(record_no_props.properties).to be_empty }
    end
    
    context 'with properties' do
      subject { record_with_props.properties }
      
      it { is_expected.to include( 'other_prop' => 'value' ) }
      it { expect(subject.length).to eq 1 }
    end
  end
  
  describe '.run_needed' do
    context 'with no properties' do
      it { expect(record_no_props.run_needed).to be_falsey }
      
      it "does set property" do
        record_no_props.run_needed = true
        expect(record_no_props.run_needed).to be true
      end
    end
    
    context 'with run-needed property' do
      it { expect(record_with_props.run_needed).to be true }
    end
  end
  
  describe '.timestamp' do
    context 'with no properties' do
      it { expect(record_no_props.timestamp).to be_nil }
      
      it "does set property" do
        record_no_props.timestamp = '2018-01-01T00:00:00.000Z'
        expect(record_no_props.timestamp).to eq '2018-01-01T00:00:00.000Z'
      end
    end

    context 'with properties' do
      it { expect(record_with_props.timestamp).to eq '2018-01-01T01:00:00.000Z' }
    end
  end
  
  describe '.stale_replicas' do
    context 'with no properties' do
      it { expect(record_no_props.stale_replicas).to be_falsey }
      
      it "does set property" do
        record_no_props.stale_replicas = true
        expect(record_no_props.stale_replicas).to be true
        record_no_props.stale_replicas = false
        expect(record_no_props.stale_replicas).to be_falsey
      end
    end
    
    context 'with stale_replicas property' do
      it { expect(record_with_props.stale_replicas).to be true }
    end
  end
  
  describe '.[]' do
    context 'with no properties' do
      subject { record_no_props }
      
      it { expect(subject['key']).to be_nil }
      
      it 'does set property' do
        subject['key'] = 'value'
        expect(subject['key']).to eq 'value'
      end
    end
    
    context 'with properties' do
      subject { record_with_props }
      
      it { expect(subject[MDF::SERVICE_TIMESTAMP]).to be_nil }
      it { expect(subject[MDF::STALE_REPLICAS]).to be_nil }
      it { expect(subject[MDF::RUN_NEEDED]).to be_nil }
      it { expect(subject['other_prop']).to eq 'value' }
    end
  end
  
end
