require 'spec_helper'
require 'longleaf/models/service_definition'
require 'longleaf/errors'

describe Longleaf::ServiceDefinition do
  describe '.initialize' do
    context 'with no work_script' do
      it { expect { build(:service_definition, work_script: nil) }.to raise_error(ArgumentError) }
    end

    context 'with no name' do
      it { expect { build(:service_definition, name: nil) }.to raise_error(ArgumentError) }
    end
  end

  describe '.work_script' do
    let(:service_def) { build(:service_definition, work_script: 'preserve.rb') }

    it { expect(service_def.work_script).to eq 'preserve.rb' }
  end

  describe '.delay' do
    let(:service_def) { build(:service_definition, delay: '10 days') }

    it { expect(service_def.delay).to eq '10 days' }
  end

  describe '.frequency' do
    let(:service_def) { build(:service_definition, frequency: '90 days') }

    it { expect(service_def.frequency).to eq '90 days' }
  end

  describe '.properties' do
    let(:service_def) { build(:service_definition, properties: { 'custom' => 'value', 'prop' => 'val' } ) }

    it { expect(service_def.properties).to include('custom' => 'value', 'prop' => 'val') }
  end
end
