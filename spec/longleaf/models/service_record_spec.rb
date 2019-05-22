require 'spec_helper'
require 'longleaf/models/service_record'
require 'longleaf/models/md_fields'

describe Longleaf::ServiceRecord do
  MDF ||= Longleaf::MDFields

  describe '.properties' do
    context 'with no properties' do
      let(:record) { build(:service_record) }

      it { expect(record.properties).to be_empty }
    end

    context 'with properties' do
      let(:record) { build(:service_record, timestamp: '2018-01-01T01:00:00.000Z', properties: {'other_prop' => 'value'}) }

      it { expect(record.properties).to include( 'other_prop' => 'value' ) }
      it { expect(record.properties.length).to eq 1 }
    end
  end

  describe '.run_needed' do
    context 'with no properties' do
      let(:record) { build(:service_record) }

      it { expect(record.run_needed).to be_falsey }

      it "does set property" do
        record.run_needed = true
        expect(record.run_needed).to be true
      end
    end

    context 'with run-needed property' do
      let(:record) { build(:service_record, run_needed: true) }

      it { expect(record.run_needed).to be true }
    end
  end

  describe '.timestamp' do
    context 'with no properties' do
      let(:record) { build(:service_record) }

      it { expect(record.timestamp).to be_nil }

      it "does set property" do
        record.timestamp = '2018-01-01T00:00:00.000Z'
        expect(record.timestamp).to eq '2018-01-01T00:00:00.000Z'
      end
    end

    context 'with property' do
      let(:record) { build(:service_record, timestamp: '2018-01-01T01:00:00.000Z') }

      it { expect(record.timestamp).to eq '2018-01-01T01:00:00.000Z' }
    end
  end

  describe '.stale_replicas' do
    context 'with no properties' do
      let(:record) { build(:service_record) }

      it { expect(record.stale_replicas).to be_falsey }

      it "does set property" do
        record.stale_replicas = true
        expect(record.stale_replicas).to be true
        record.stale_replicas = false
        expect(record.stale_replicas).to be_falsey
      end
    end

    context 'with stale_replicas property' do
      let(:record) { build(:service_record, stale_replicas: true) }

      it { expect(record.stale_replicas).to be true }
    end
  end

  describe '.[]' do
    context 'with no properties' do
      let(:record) { build(:service_record) }

      it { expect(record['key']).to be_nil }

      it 'does set property' do
        record['key'] = 'value'
        expect(record['key']).to eq 'value'
      end
    end

    context 'with properties' do
      let(:record) { build(:service_record, properties: {'other_prop' => 'value'}) }

      it { expect(record['not_present']).to be_nil }
      it { expect(record['other_prop']).to eq 'value' }
    end
  end
end
