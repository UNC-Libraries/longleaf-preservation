require 'spec_helper'
require 'longleaf/services/service_definition_validator'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/config_validator_helpers'

describe Longleaf::ServiceDefinitionValidator do
  include Longleaf::ConfigValidatorHelpers

  AF ||= Longleaf::AppFields
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:validator) { build(:service_definition_validator, config: config) }

  describe '#validate_config' do
    context 'with non-hash config' do
      let(:config) { 'bad' }

      it { fails_validation_with_error(validator, /must be a hash/) }
    end

    context 'with no services field' do
      let(:config) { {} }

      it { fails_validation_with_error(validator, /must contain a root 'services'/) }
    end

    context 'with invalid services value' do
      let(:config) { ConfigBuilder.new.with_services('bad').get }

      it { fails_validation_with_error(validator, /must be a hash of services/) }
    end

    context 'with empty services' do
      let(:config) { ConfigBuilder.new.with_services.get }

      it { passes_validation(validator) }
    end

    context 'with service missing work_script' do
      let(:config) { ConfigBuilder.new.with_service(name: 'serv1', work_script: nil).get }

      it { fails_validation_with_error(validator, /Service definition 'serv1' must specify a 'work_script'/) }
    end

    context 'service with empty work_script field' do
      let(:config) { ConfigBuilder.new.with_service(name: 'serv1', work_script: '').get }

      it { fails_validation_with_error(validator, /Service definition 'serv1' must specify a 'work_script'/) }
    end

    context 'service with invalid name' do
      let(:config) { ConfigBuilder.new.with_service(name: { 'random' => 'stuff' } ).get }

      it { fails_validation_with_error(validator, /Name of service definition must be a string/) }
    end

    context 'with valid service' do
      let(:config) { ConfigBuilder.new.with_service(name: 'serv1').get }

      it { passes_validation(validator) }
    end

    context 'with multiple valid services' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1', work_script: 'script1.rb')
          .with_service(name: 'serv2', work_script: 'script2.rb')
          .get
      }

      it { passes_validation(validator) }
    end

    context 'with multiple invalid services' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 1, work_script: 'script1.rb')
          .with_service(name: 'serv2', work_script: '')
          .get
      }

      it 'returns both errors' do
        fails_validation_with_error(validator,
            /Name of service definition must be a string/,
            /Service definition 'serv2' must specify a 'work_script' property/)
      end
    end
  end

  def fails_validation_with_error(validator, *error_messages)
    result = validator.validate_config
    expect(result.valid?).to be false
    error_messages.each do |error_message|
      expect(result.errors).to include(error_message)
    end
  end

  def passes_validation(validator)
    result = validator.validate_config
    expect(result.valid?).to eq(true), "expected validation to pass, but received errors:\n#{result.errors&.join("\n")}"
  end
end
