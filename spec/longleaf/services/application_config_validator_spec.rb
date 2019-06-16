require 'spec_helper'
require 'longleaf/services/application_config_validator'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'
require 'fileutils'
require 'tmpdir'

describe Longleaf::ApplicationConfigValidator do
  AppValidator ||= Longleaf::ApplicationConfigValidator
  ConfigBuilder ||= Longleaf::ConfigBuilder

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
          .get
      }

      it { expect { AppValidator::validate(config) }.to raise_error(Longleaf::ConfigurationError) }
    end

    context 'invalid service configuration' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1', work_script: nil)
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .get
      }

      it { expect { AppValidator::validate(config) }.to raise_error(Longleaf::ConfigurationError) }
    end

    context 'invalid mapping configuration' do
      let(:config) {
        ConfigBuilder.new
          .with_services
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', 'serv_none')
          .get
      }

      it { expect { AppValidator::validate(config) }.to raise_error(Longleaf::ConfigurationError) }
    end

    context 'minimal configuration' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', 'serv1')
          .get
      }

      it { expect { AppValidator::validate(config) }.to_not raise_error }
    end
  end
end
