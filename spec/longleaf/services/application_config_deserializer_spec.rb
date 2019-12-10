require 'spec_helper'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/system_config_builder'
require 'longleaf/specs/file_helpers'
require 'fileutils'
require 'tmpdir'
require 'tempfile'

describe Longleaf::ApplicationConfigDeserializer do
  include Longleaf::FileHelpers
  AppDeserializer ||= Longleaf::ApplicationConfigDeserializer
  ConfigBuilder ||= Longleaf::ConfigBuilder
  SysConfigBuilder ||= Longleaf::SystemConfigBuilder

  describe '#deserialize' do
    context 'invalid file contents' do
      let(:config_path) {
        Tempfile.open('config') do |f|
          f.write('bad : yaml : time')
          return f.path
        end
      }

      it { expect { AppDeserializer::deserialize(config_path) }.to raise_error(Longleaf::ConfigurationError) }
    end

    context 'config file does not exist' do
      let(:config_path) {
        config_file = Tempfile.new('config')
        config_path = config_file.path
        config_file.delete
        config_path
      }

      it {
        expect { AppDeserializer::deserialize(config_path) }.to raise_error(Longleaf::ConfigurationError,
          /Configuration file .* does not exist/)
      }
    end

    context 'invalid configuration' do
      let(:config_path) {
        ConfigBuilder.new
          .with_services
          .with_service(name: 'serv1')
          .with_locations
          .with_location(name: 'loc1', path: nil, md_path: nil)
          .map_services('loc1', 'serv1')
          .write_to_yaml_file
      }

      it { expect { AppDeserializer::deserialize(config_path) }.to raise_error(Longleaf::ConfigurationError) }
    end

    context 'with relative locations' do
      let!(:config_path) {
        ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1', path: 'fpath', md_path: 'metadata')
          .map_services('loc1', 'serv1')
          .write_to_yaml_file
      }
      let(:config_dir) { Pathname.new(config_path).parent.to_s }
      let!(:md_dir) { make_test_dir(parent: config_dir, name: 'metadata') }
      let!(:path_dir) { make_test_dir(parent: config_dir, name: 'fpath') }

      after do
        FileUtils.rmdir([md_dir, path_dir])
      end

      it 'returns location loc1 with absolute paths based off location of config' do
        result = AppDeserializer::deserialize(config_path)
        expect(result.location_manager).to_not be_nil

        loc = result.location_manager.locations['loc1']

        expect(loc.path).to eq path_dir + '/'
        expect(loc.metadata_location.path).to eq md_dir + '/'
      end

      context 'with relative path to config file' do
        let(:relative_config) { Pathname.new(config_path).relative_path_from(Pathname.new(Dir.pwd)) }

        it 'returns location loc1 with absolute paths based off location of config' do
          result = AppDeserializer::deserialize(relative_config)
          expect(result.location_manager).to_not be_nil

          loc = result.location_manager.locations['loc1']

          expect(loc.path).to eq path_dir + '/'
          expect(loc.metadata_location.path).to eq md_dir + '/'
        end
      end
    end

    context 'with path modifiers in locations' do
      let(:md_pathname) { Pathname.new(make_test_dir(name: 'metadata')) }
      let(:path_pathname) { Pathname.new(make_test_dir(name: 'path')) }
      let(:modified_path) { File.join(path_pathname.parent, "./subdir/..", path_pathname.basename) }
      let(:modified_md) { File.join(path_pathname.parent, "./another/..", md_pathname.basename) }
      let!(:config_path) {
        ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1', path: modified_path, md_path: modified_md)
          .map_services('loc1', 'serv1')
          .write_to_yaml_file
      }

      after do
        FileUtils.rmdir([md_pathname, path_pathname])
      end

      it 'returns location loc1 with absolute paths and no modifiers' do
        result = AppDeserializer::deserialize(config_path)
        expect(result.location_manager).to_not be_nil

        loc = result.location_manager.locations['loc1']

        expect(loc.path).to eq path_pathname.to_s + '/'
        expect(loc.metadata_location.path).to eq md_pathname.to_s + '/'
      end
    end

    context 'with uri location paths' do
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:path_dir) { 'http://s3.example.com/stuff' }
      let!(:config_path) {
        ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1', path: path_dir, s_type: 's3', md_path: md_dir)
          .map_services('loc1', 'serv1')
          .write_to_yaml_file
      }

      after(:each) do
        FileUtils.rmdir([md_dir])
      end

      it 'returns location loc1 with unmodified uris' do
        result = AppDeserializer::deserialize(config_path)
        expect(result.location_manager).to_not be_nil

        loc = result.location_manager.locations['loc1']

        expect(loc.path).to eq path_dir + '/'
        expect(loc.metadata_location.path).to eq md_dir + '/'
      end
    end

    context 'minimal service configuration' do
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:path_dir) { Dir.mktmpdir('path') }
      let!(:config_path) {
        ConfigBuilder.new
          .with_services
          .with_service(name: 'serv1')
          .with_locations
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', 'serv1')
          .write_to_yaml_file
      }

      let!(:config_md5) { Digest::MD5.file(config_path).hexdigest }

      after(:each) do
        FileUtils.rmdir([md_dir, path_dir])
      end

      context 'without system config' do
        it {
          result = AppDeserializer::deserialize(config_path)
          expect(result.service_manager).to_not be_nil
          expect(result.location_manager).to_not be_nil
          expect(result.config_md5).to eq config_md5
          expect(result.index_manager).to be_kind_of(Longleaf::IndexManager)
          expect(result.index_manager.using_index?).to be false
        }
      end

      context 'with relative config file location' do
        let(:relative_config_path) { Pathname.new(config_path).relative_path_from(Pathname.new(Dir.pwd)) }

        it "resolves config path and loads correctly" do
          result = AppDeserializer::deserialize(relative_config_path)

          expect(result.service_manager).to_not be_nil
          expect(result.location_manager).to_not be_nil
          expect(result.config_md5).to eq config_md5
          expect(result.index_manager).to be_kind_of(Longleaf::IndexManager)
          expect(result.index_manager.using_index?).to be false
        end
      end

      context 'with index config' do
        let(:sys_config) {
          SysConfigBuilder.new
            .with_index('amalgalite', 'amalgalite://tmp/db')
            .get
        }
        let!(:config_path) {
          ConfigBuilder.new
            .with_services
            .with_service(name: 'serv1')
            .with_locations
            .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
            .map_services('loc1', 'serv1')
            .with_system(sys_config)
            .write_to_yaml_file
        }

        it {
          result = AppDeserializer::deserialize(config_path)
          expect(result.service_manager).to_not be_nil
          expect(result.location_manager).to_not be_nil
          expect(result.config_md5).to eq config_md5
          expect(result.index_manager).to be_kind_of(Longleaf::IndexManager)
          expect(result.index_manager.using_index?).to be true
        }
      end
    end
  end
end
