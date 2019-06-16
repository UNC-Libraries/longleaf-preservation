require 'spec_helper'
require 'longleaf/services/service_mapping_validator'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/config_validator_helpers'

describe Longleaf::ServiceMappingValidator do
  include Longleaf::ConfigValidatorHelpers

  AF ||= Longleaf::AppFields
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:validator) { build(:service_mapping_validator, config: config) }

  describe '#validate_config' do
    context 'with non-hash config' do
      let(:config) { 'bad' }

      it { fails_validation_with_error(validator, /must be a hash/) }
    end

    context 'with no mappings field' do
      let(:config) { {} }

      it { fails_validation_with_error(validator, /must contain a root 'service_mappings'/) }
    end

    context 'with invalid mappings value' do
      let(:config) { ConfigBuilder.new.with_mappings('bad').get }

      it { fails_validation_with_error(validator, /'#{AF::SERVICE_MAPPINGS}' must be an array of mappings/) }
    end

    context 'with empty mappings' do
      let(:config) { ConfigBuilder.new.with_mappings.get }

      it { passes_validation(validator) }
    end

    context 'mapping missing locations field' do
      let(:config) {
        ConfigBuilder.new
          .with_locations
          .with_service(name: 'serv1')
          .map_services(nil, 'serv1').get
      }

      it { fails_validation_with_error(validator, /must contain a '#{AF::LOCATIONS}' field/) }
    end

    context 'mapping with blank locations field' do
      let(:config) {
        ConfigBuilder.new
          .with_location(name: 'loc1')
          .with_service(name: 'serv1')
          .map_services('', 'serv1').get
      }

      it { fails_validation_with_error(validator, /must specify one or more value in the '#{AF::LOCATIONS}' field/) }
    end

    context 'mapping with empty locations field' do
      let(:config) {
        ConfigBuilder.new
          .with_location(name: 'loc1')
          .with_service(name: 'serv1')
          .map_services([], 'serv1').get
      }

      it { fails_validation_with_error(validator, /must specify one or more value in the '#{AF::LOCATIONS}' field/) }
    end

    context 'mapping missing services field' do
      let(:config) {
        ConfigBuilder.new
          .with_location(name: 'loc1')
          .with_services
          .map_services('loc1', nil).get
      }

      it { fails_validation_with_error(validator, /must contain a '#{AF::SERVICES}' field/) }
    end

    context 'mapping with blank services field' do
      let(:config) {
        ConfigBuilder.new
          .with_location(name: 'loc1')
          .with_service(name: 'serv1')
          .map_services('loc1', '').get
      }

      it { fails_validation_with_error(validator, /must specify one or more value in the '#{AF::SERVICES}' field/) }
    end

    context 'mapping with empty services field' do
      let(:config) {
        ConfigBuilder.new
          .with_location(name: 'loc1')
          .with_service(name: 'serv1')
          .map_services('loc1', []).get
      }

      it { fails_validation_with_error(validator, /must specify one or more value in the '#{AF::SERVICES}' field/) }
    end

    context 'mapping to location which does not exist' do
      let(:config) {
        ConfigBuilder.new
          .with_locations
          .with_service(name: 'serv1')
          .map_services('loc1', 'serv1').get
      }

      it { fails_validation_with_error(validator, /'loc1', but no #{AF::LOCATIONS} with that name exist/) }
    end

    context 'mapping to service which does not exist' do
      let(:config) {
        ConfigBuilder.new
          .with_services
          .with_location(name: 'loc1')
          .map_services('loc1', 'serv1').get
      }

      it { fails_validation_with_error(validator, /'serv1', but no #{AF::SERVICES} with that name exist/) }
    end

    context 'with one to one service mapping' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1')
          .map_services('loc1', 'serv1').get
      }

      it { passes_validation(validator) }
    end

    context 'mapping to service which does not exist and mapping to location that does not exist' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1')
          .map_services('loc1', 'serv_none')
          .map_services('loc_none', 'serv1').get
      }

      it 'returns multiple failures' do
        fails_validation_with_error(validator,
          /Mapping specifies value 'serv_none', but no services with that name exist/,
          /Mapping specifies value 'loc_none', but no locations with that name exist/)
      end
    end

    context 'mapping to multiple services which do not exist' do
      let(:config) {
        ConfigBuilder.new
          .with_services
          .with_location(name: 'loc1')
          .map_services('loc1', ['serv_none', 'never_serve']).get
      }

      it 'returns multiple failures' do
        fails_validation_with_error(validator,
          /Mapping specifies value 'serv_none', but no services with that name exist/,
          /Mapping specifies value 'never_serve', but no services with that name exist/)
      end
    end


    context 'with one location to multiple services mapping' do
      let(:config) {
        ConfigBuilder.new
          .with_services.with_service(name: 'serv1').with_service(name: 'serv2')
          .with_locations.with_location(name: 'loc1')
          .map_services('loc1', ['serv1', 'serv2']).get
      }

      it { passes_validation(validator) }
    end

    context 'with multiple locations to multiple services mapping' do
      let(:config) {
        ConfigBuilder.new
          .with_services.with_service(name: 'serv1').with_service(name: 'serv2')
          .with_locations.with_location(name: 'loc1').with_location(name: 'loc2')
          .map_services(['loc1', 'loc2'], ['serv1', 'serv2']).get
      }

      it { passes_validation(validator) }
    end
  end
end
