require 'spec_helper'
require 'longleaf/helpers/service_date_helper'

describe Longleaf::ServiceDateHelper do
  ServiceDateHelper ||= Longleaf::ServiceDateHelper

  describe '#add_to_timestamp' do
    let(:timestamp) { "2010-10-31T01:00:00Z" }

    it 'adds 1 second' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "1 second")).to eq "2010-10-31T01:00:01Z"
    end

    it 'adds 5 seconds' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "5 seconds")).to eq "2010-10-31T01:00:05Z"
    end

    it 'adds 5 minutes' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "5 minutes")).to eq "2010-10-31T01:05:00Z"
    end

    it 'adds 25 hours' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "25 hours")).to eq "2010-11-01T02:00:00Z"
    end

    it 'adds 2 days' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "2 days")).to eq "2010-11-02T01:00:00Z"
    end

    it 'adds 2 weeks' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "2 weeks")).to eq "2010-11-14T01:00:00Z"
    end

    it 'adds 2 months' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "2 months")).to eq "2010-12-30T01:00:00Z"
    end

    it 'adds 5 years' do
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "5 years")).to eq "2015-10-30T01:00:00Z"
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
      expect(ServiceDateHelper.add_to_timestamp(timestamp, "5 days, immediate")).to eq "2010-11-05T01:00:00Z"
    end

    it 'rejects negative quantity' do
      expect { ServiceDateHelper.add_to_timestamp(timestamp, "-2 months") }.to raise_error(ArgumentError)
    end
  end
end
