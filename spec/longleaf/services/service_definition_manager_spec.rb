require 'spec_helper'
require 'longleaf/services/service_definition_manager'
require 'longleaf/specs/config_builder'

describe Longleaf::ServiceDefinitionManager do
  ConfigBuilder ||= Longleaf::ConfigBuilder

  describe '.initialize' do
    context 'with empty config' do
      it { expect { build(:service_definition_manager) }.to raise_error(ArgumentError) }
    end
  end

  describe '.services' do
    context 'with no services' do
      let(:config) { ConfigBuilder.new.with_services.get }
      let(:manager) { build(:service_definition_manager, config: config) }

      it { expect(manager.services).to be_empty }
    end

    context 'with valid services' do
      let(:config) { ConfigBuilder.new.with_services.with_service(name: 'serv1', work_script: 'preserve.rb').get }
      let(:manager) { build(:service_definition_manager, config: config) }

      it { expect(manager.services).to_not be_empty }
      it 'returns service serv1' do
        service = manager.services['serv1']

        expect(service.name).to eq 'serv1'
        expect(service.work_script).to eq 'preserve.rb'
        expect(service.properties).to be_empty
      end
    end

    context 'service with all properties' do
      let(:config) {
        ConfigBuilder.new.with_services
          .with_service(name: 'serv1',
              work_script: 'preserve.rb',
              work_class: 'PreserveStuff',
              delay: '1 day',
              frequency: '3 months',
              properties: { 'priority' => '1' })
          .get
      }
      let(:manager) { build(:service_definition_manager, config: config) }

      it { expect(manager.services).to_not be_empty }
      it 'returns service serv1' do
        service = manager.services['serv1']

        expect(service.name).to eq 'serv1'
        expect(service.work_script).to eq 'preserve.rb'
        expect(service.work_class).to eq 'PreserveStuff'
        expect(service.delay).to eq '1 day'
        expect(service.frequency).to eq '3 months'
        expect(service.properties).to include('priority' => '1')
      end
    end

    context 'with multiple services' do
      let(:config) {
        ConfigBuilder.new.with_services
          .with_service(name: 'serv1', work_script: 'preserve.rb')
          .with_service(name: 'serv2', work_script: 'replicate.rb')
          .get
      }
      let(:manager) { build(:service_definition_manager, config: config) }

      it { expect(manager.services).to_not be_empty }
      it { expect(manager.services.length).to eq 2 }

      it 'returns service serv1' do
        service = manager.services['serv1']

        expect(service.name).to eq 'serv1'
        expect(service.work_script).to eq 'preserve.rb'
      end

      it 'returns service serv2' do
        service = manager.services['serv2']

        expect(service.name).to eq 'serv2'
        expect(service.work_script).to eq 'replicate.rb'
      end
    end
  end
end
