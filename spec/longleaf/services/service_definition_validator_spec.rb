require 'spec_helper'
require 'longleaf/services/service_definition_validator'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'

describe Longleaf::ServiceDefinitionValidator do
  AF ||= Longleaf::AppFields
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:validator) { Longleaf::ServiceDefinitionValidator }

  describe '#validate_config' do
    context 'with non-hash config' do
      it { expect { validator::validate_config('bad') }.to raise_error(Longleaf::ConfigurationError, /must be a hash/) }
    end

    context 'with no services field' do
      it {
        expect { validator::validate_config({}) }.to raise_error(Longleaf::ConfigurationError,
          /must contain a root 'services'/)
      }
    end

    context 'with invalid services value' do
      let(:config) { ConfigBuilder.new.with_services('bad').get }

      it { expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError, /must be a hash of services/) }
    end

    context 'with empty services' do
      let(:config) { ConfigBuilder.new.with_services.get }

      it { expect { validator::validate_config(config) }.to_not raise_error }
    end

    context 'with service missing work_script' do
      let(:config) { ConfigBuilder.new.with_services.with_service(name: 'serv1', work_script: nil).get }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /Service definition 'serv1' must specify a 'work_script'/)
      }
    end

    context 'service with empty work_script field' do
      let(:config) { ConfigBuilder.new.with_services.with_service(name: 'serv1', work_script: '').get }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /Service definition 'serv1' must specify a 'work_script'/)
      }
    end

    context 'service with invalid name' do
      let(:config) {
        ConfigBuilder.new.with_services
          .with_service(name: { 'random' => 'stuff' } ).get
      }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /Name of service definition must be a string/)
      }
    end

    context 'with valid service' do
      let(:config) {
        ConfigBuilder.new.with_services
          .with_service(name: 'serv1').get
      }

      it { expect { validator::validate_config(config) }.to_not raise_error }
    end

    context 'with multiple valid services' do
      let(:config) {
        ConfigBuilder.new.with_services
          .with_service(name: 'serv1', work_script: 'script1.rb')
          .with_service(name: 'serv2', work_script: 'script2.rb')
          .get
      }

      it { expect { validator::validate_config(config) }.to_not raise_error }
    end
  end
end
