require 'spec_helper'
require 'longleaf/helpers/service_date_helper'
require 'longleaf/specs/metadata_builder'

describe Longleaf::ServiceDateHelper do
  ServiceDateHelper ||= Longleaf::ServiceDateHelper
  MetadataBuilder ||= Longleaf::MetadataBuilder
  SECONDS_IN_DAY ||= 60 * 60 * 24

  describe '#add_to_timestamp' do
    let(:timestamp) { "2010-10-31T01:00:00Z" }

    it 'adds 1 second' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "1 second")).to eq "2010-10-31T01:00:01.000Z"
    end

    it 'adds 5 seconds' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "5 seconds")).to eq "2010-10-31T01:00:05.000Z"
    end

    it 'adds 5 minutes' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "5 minutes")).to eq "2010-10-31T01:05:00.000Z"
    end

    it 'adds 25 hours' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "25 hours")).to eq "2010-11-01T02:00:00.000Z"
    end

    it 'adds 2 days' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "2 days")).to eq "2010-11-02T01:00:00.000Z"
    end

    it 'adds 2 weeks' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "2 weeks")).to eq "2010-11-14T01:00:00.000Z"
    end

    it 'adds 2 months' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "2 months")).to eq "2010-12-30T01:00:00.000Z"
    end

    it 'adds 5 years' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "5 years")).to eq "2015-10-30T01:00:00.000Z"
    end

    it 'rejects invalid unit' do
      expect { ServiceDateHelper.add_to_timestamp(timestamp, "5 boxys") }.to raise_error(ArgumentError)
    end

    it 'rejects non-numeric quantity' do
      expect { ServiceDateHelper.add_to_timestamp(timestamp, "many days") }.to raise_error(ArgumentError)
    end

    it 'rejects missing quantity' do
      expect { ServiceDateHelper.add_to_timestamp(timestamp, "seconds") }.to raise_error(ArgumentError)
    end

    it 'rejects non-ISO-8601 timestamp' do
      expect { ServiceDateHelper.add_to_timestamp("10/10/2010", "1 second") }.to raise_error(ArgumentError)
    end

    it 'adds days with extra parameters' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "5 days, immediate")).to eq "2010-11-05T01:00:00.000Z"
    end

    it 'rejects negative quantity' do
      expect { ServiceDateHelper.add_to_timestamp(timestamp, "-2 months") }.to raise_error(ArgumentError)
    end
  end

  describe '#next_run_needed' do
    context 'md_rec is nil' do
      let(:service_def) { build(:service_definition) }

      it { expect { ServiceDateHelper.next_run_needed(nil, service_def) }.to raise_error(ArgumentError) }
    end

    context 'service_def is nil' do
      let(:md_rec) { build(:metadata_record) }

      it { expect { ServiceDateHelper.next_run_needed(md_rec, nil) }.to raise_error(ArgumentError) }
    end


    context 'service_rec is nil' do
      let(:registered) { ServiceDateHelper::formatted_timestamp(Time.new(2019, 6, 1, 0, 0, 0, "+00:00")) }
      let(:md_rec) { build(:metadata_record, registered: registered) }

      context 'service definition without delay' do
        let(:service_def) { build(:service_definition, name: 'serv1') }

        it 'returns registered time of file' do
          expect(ServiceDateHelper.next_run_needed(md_rec, service_def)).to eq registered
        end
      end

      context 'service definition with 5 day delay' do
        let(:service_def) { build(:service_definition, name: 'serv1', delay: '5 days') }

        it 'returns timestamp 5 days from registered time' do
          expect(ServiceDateHelper.next_run_needed(md_rec, service_def)).to eq '2019-06-06T00:00:00.000Z'
        end
      end
    end

    context 'service timestamp is nil' do
      let(:registered) { ServiceDateHelper::formatted_timestamp(Time.new(2019, 6, 1, 0, 0, 0, "+00:00")) }
      let(:md_rec) do
        MetadataBuilder.new(registered: registered)
            .with_service('serv1', timestamp: nil)
            .get_metadata_record
      end

      context 'service definition without delay' do
        let(:service_def) { build(:service_definition, name: 'serv1') }

        it 'returns the registered time' do
          expect(ServiceDateHelper.next_run_needed(md_rec, service_def)).to eq registered
        end
      end

      context 'service definition with 5 day delay' do
        let(:service_def) { build(:service_definition, name: 'serv1', delay: '5 days') }

        it 'returns timestamp 5 days from registered time' do
          expect(ServiceDateHelper.next_run_needed(md_rec, service_def)).to eq '2019-06-06T00:00:00.000Z'
        end
      end

      context 'service definition invalid delay' do
        let(:service_def) { build(:service_definition, name: 'serv1', delay: 'bad time') }

        it { expect { ServiceDateHelper.next_run_needed(md_rec, service_def) }.to raise_error(ArgumentError) }
      end

      context 'with 5 day delay and 6 day frequency' do
        let(:service_def) { build(:service_definition, name: 'serv1', delay: '5 days', frequency: '6 days') }

        it 'returns timestamp 5 days from registered, based off of delay only' do
          expect(ServiceDateHelper.next_run_needed(md_rec, service_def)).to eq '2019-06-06T00:00:00.000Z'
        end
      end
    end

    context 'service timestamp is provided' do
      let(:service_timestamp) { ServiceDateHelper::formatted_timestamp(Time.new(2019, 5, 2, 0, 0, 0, "+00:00")) }
      let(:md_rec) do
        MetadataBuilder.new
            .with_service('serv1', timestamp: service_timestamp)
            .get_metadata_record
      end

      context 'service frequency is nil' do
        let(:service_def) { build(:service_definition, name: 'serv1') }

        # Service does not need to run again
        it { expect(ServiceDateHelper.next_run_needed(md_rec, service_def)).to be_nil }
      end

      context 'service definition with frequency of 6 days' do
        let(:service_def) { build(:service_definition, name: 'serv1', frequency: '6 days') }

        it 'returns timestamp 6 days after service timestamp' do
          expect(ServiceDateHelper.next_run_needed(md_rec, service_def)).to eq '2019-05-08T00:00:00.000Z'
        end
      end

      context 'service definition with invalid frequency' do
        let(:service_def) { build(:service_definition, name: 'serv1', frequency: 'bad frequencies') }

        it { expect { ServiceDateHelper.next_run_needed(md_rec, service_def) }.to raise_error(ArgumentError) }
      end

      context 'with 5 day delay and 6 day frequency' do
        let(:service_def) { build(:service_definition, name: 'serv1', delay: '5 days', frequency: '6 days') }

        it 'returns timestamp 6 days after service timestamp, based off frequency' do
          expect(ServiceDateHelper.next_run_needed(md_rec, service_def)).to eq '2019-05-08T00:00:00.000Z'
        end
      end
    end
  end
end
