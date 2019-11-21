require 'spec_helper'
require 'longleaf/services/application_config_validator'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/config_validator_helpers'
require 'fileutils'
require 'tmpdir'

describe Longleaf::ApplicationConfigValidator do
  include Longleaf::ConfigValidatorHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:validator) { build(:application_config_validator, config: config) }

  let(:md_dir) { Dir.mktmpdir('metadata') }
  let(:path_dir) { Dir.mktmpdir('path') }

  after do
    FileUtils.rm_rf([md_dir, path_dir])
  end

  describe '#validate' do
    context 'invalid location configuration' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1', path: nil, md_path: md_dir)
          .with_mappings
          .get
      }

      it { fails_validation_with_error(validator, /'loc1' specifies invalid location 'path' property/) }
    end

    context 'invalid service configuration' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1', work_script: nil)
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .with_mappings
          .get
      }

      it { fails_validation_with_error(validator, /'serv1' must specify a 'work_script' property/) }
    end

    context 'invalid mapping configuration' do
      let(:config) {
        ConfigBuilder.new
          .with_services
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', 'serv_none')
          .get
      }

      it { fails_validation_with_error(validator, /'serv_none', but no services with that name exist/) }
    end

    context 'minimal configuration' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', 'serv1')
          .get
      }

      it { passes_validation(validator) }
    end

    context 'invalid mapping, location and service' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1', work_script: nil)
          .with_location(name: 'loc1', path: nil, md_path: md_dir)
          .map_services('loc1', 'serv_none')
          .get
      }

      it 'reports all failures' do
        fails_validation_with_error(validator,
            /'loc1' specifies invalid location 'path' property/,
            /'serv1' must specify a 'work_script' property/,
            /'serv_none', but no services with that name exist/)
      end
    end
  end
end
