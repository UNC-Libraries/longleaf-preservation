require 'spec_helper'
require 'longleaf/services/service_mapping_validator'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'

describe Longleaf::ServiceMappingValidator do
  AF ||= Longleaf::AppFields
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:validator) { Longleaf::ServiceMappingValidator }

  describe '#validate_config' do
    context 'with non-hash config' do
      it { expect { validator::validate_config('bad') }.to raise_error(Longleaf::ConfigurationError, /must be a hash/) }
    end

    context 'with no mappings field' do
      it { expect { validator::validate_config({}) }.to raise_error(Longleaf::ConfigurationError, /must contain a root 'service_mappings'/) }
    end

    context 'with invalid mappings value' do
      let(:config) { ConfigBuilder.new.with_mappings('bad').get }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /'#{AF::SERVICE_MAPPINGS}' must be an array of mappings/)
      }
    end

    context 'with empty mappings' do
      let(:config) { ConfigBuilder.new.with_mappings.get }

      it { expect { validator::validate_config(config) }.to_not raise_error }
    end

    context 'mapping missing locations field' do
      let(:config) {
        ConfigBuilder.new
        .with_locations
        .with_services.with_service(name: 'serv1')
        .map_services(nil, 'serv1').get
      }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /must contain a '#{AF::LOCATIONS}' field/)
      }
    end

    context 'mapping with blank locations field' do
      let(:config) {
        ConfigBuilder.new
          .with_locations.with_location(name: 'loc1')
          .with_services.with_service(name: 'serv1')
          .map_services('', 'serv1').get
      }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /must specify one or more value in the '#{AF::LOCATIONS}' field/)
      }
    end

    context 'mapping with empty locations field' do
      let(:config) {
        ConfigBuilder.new
          .with_locations.with_location(name: 'loc1')
          .with_services.with_service(name: 'serv1')
          .map_services([], 'serv1').get
      }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /must specify one or more value in the '#{AF::LOCATIONS}' field/)
      }
    end

    context 'mapping missing services field' do
      let(:config) {
        ConfigBuilder.new
          .with_locations.with_location(name: 'loc1')
          .with_services
          .map_services('loc1', nil).get
      }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /must contain a '#{AF::SERVICES}' field/)
      }
    end

    context 'mapping with blank services field' do
      let(:config) {
        ConfigBuilder.new
          .with_locations.with_location(name: 'loc1')
          .with_services.with_service(name: 'serv1')
          .map_services('loc1', '').get
      }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /must specify one or more value in the '#{AF::SERVICES}' field/)
      }
    end

    context 'mapping with empty services field' do
      let(:config) {
        ConfigBuilder.new
          .with_locations.with_location(name: 'loc1')
          .with_services.with_service(name: 'serv1')
          .map_services('loc1', []).get
      }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /must specify one or more value in the '#{AF::SERVICES}' field/)
      }
    end

    context 'mapping to location which does not exist' do
      let(:config) {
        ConfigBuilder.new
          .with_locations
          .with_services.with_service(name: 'serv1')
          .map_services('loc1', 'serv1').get
      }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /'loc1', but no #{AF::LOCATIONS} with that name exist/)
      }
    end

    context 'mapping to service which does not exist' do
      let(:config) {
        ConfigBuilder.new
          .with_services
          .with_locations.with_location(name: 'loc1')
          .map_services('loc1', 'serv1').get
      }

      it {
        expect { validator::validate_config(config) }.to raise_error(Longleaf::ConfigurationError,
          /'serv1', but no #{AF::SERVICES} with that name exist/)
      }
    end

    context 'with one to one service mapping' do
      let(:config) {
        ConfigBuilder.new
          .with_services.with_service(name: 'serv1')
          .with_locations.with_location(name: 'loc1')
          .map_services('loc1', 'serv1').get
      }

      it { expect { validator::validate_config(config) }.to_not raise_error }
    end

    context 'with one location to multiple services mapping' do
      let(:config) {
        ConfigBuilder.new
          .with_services.with_service(name: 'serv1').with_service(name: 'serv2')
          .with_locations.with_location(name: 'loc1')
          .map_services('loc1', ['serv1', 'serv2']).get
      }

      it { expect { validator::validate_config(config) }.to_not raise_error }
    end

    context 'with multiple locations to multiple services mapping' do
      let(:config) {
        ConfigBuilder.new
          .with_services.with_service(name: 'serv1').with_service(name: 'serv2')
          .with_locations.with_location(name: 'loc1').with_location(name: 'loc2')
          .map_services(['loc1', 'loc2'], ['serv1', 'serv2']).get
      }

      it { expect { validator::validate_config(config) }.to_not raise_error }
    end
  end
end
