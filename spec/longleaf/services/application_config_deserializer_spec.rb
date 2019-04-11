require 'spec_helper'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'
require 'fileutils'
require 'tmpdir'
require 'tempfile'

describe Longleaf::ApplicationConfigDeserializer do
  AppDeserializer ||= Longleaf::ApplicationConfigDeserializer
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
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
      
      it { expect { AppDeserializer::deserialize(config_path) }.to raise_error(Longleaf::ConfigurationError,
          /Configuration file .* does not exist/) }
    end
    
    context 'invalid configuration' do
      let(:config_path) { ConfigBuilder.new
          .with_services
          .with_service(name: 'serv1')
          .with_locations
          .with_location(name: 'loc1', path: nil, md_path: nil)
          .map_services('loc1', 'serv1')
          .write_to_yaml_file }
      
          it { expect { AppDeserializer::deserialize(config_path) }.to raise_error(Longleaf::ConfigurationError) }
    end
    
    context 'minimal configuration' do
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:path_dir) { Dir.mktmpdir('path') }
      let(:config_path) { ConfigBuilder.new
          .with_services
          .with_service(name: 'serv1')
          .with_locations
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', 'serv1')
          .write_to_yaml_file }
      
      let(:config_md5) { Digest::MD5.file(config_path).hexdigest }
      
      after(:each) do
        FileUtils.rmdir([md_dir, path_dir])
      end
      
      it {
        result = AppDeserializer::deserialize(config_path)
        expect(result.service_manager).to_not be_nil
        expect(result.location_manager).to_not be_nil
        expect(result.config_md5).to eq config_md5
      }
    end
  end
end
    