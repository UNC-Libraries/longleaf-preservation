require 'spec_helper'
require 'longleaf/services/system_config_deserializer'
require 'longleaf/services/system_config_manager'
require 'longleaf/errors'
require 'longleaf/specs/system_config_builder'
require 'fileutils'
require 'tmpdir'
require 'tempfile'

describe Longleaf::SystemConfigDeserializer do
  SysDeserializer ||= Longleaf::SystemConfigDeserializer
  SysConfigBuilder ||= Longleaf::SystemConfigBuilder
  
  let(:app_config_manager) { build(:application_config_manager) }
  
  describe '#deserialize' do
    # no config path
    # config path does not exist
    # not a yaml file
    # valid config
    
    context 'invalid file contents' do
      let(:config_path) {
        Tempfile.open('config') do |f|
          f.write('bad : yaml : time')
          return f.path
        end
      }
      
      it { expect { SysDeserializer::deserialize(config_path, app_config_manager) }.to raise_error(Longleaf::ConfigurationError) }
    end
    
    context 'config file does not exist' do
      let(:config_path) {
        config_file = Tempfile.new('config')
        config_path = config_file.path
        config_file.delete
        config_path
      }
      
      it { expect { SysDeserializer::deserialize(config_path, app_config_manager) }.to raise_error(Longleaf::ConfigurationError,
          /System configuration file .* does not exist/) }
    end
    
    context 'minimal configuration' do
      let(:config_path) { SysConfigBuilder.new
          .write_to_yaml_file }
      
      it 'returns a SystemConfigManager' do
        result = SysDeserializer::deserialize(config_path, app_config_manager)
        expect(result).to be_a(Longleaf::SystemConfigManager)
      end
    end
    
    context 'configuration with index' do
      let(:config_path) { SysConfigBuilder.new
          .with_index('postgres', 'localhost')
          .write_to_yaml_file }
      
      it 'returns a SystemConfigManager with an index driver' do
        result = SysDeserializer::deserialize(config_path, app_config_manager)
        expect(result).to be_a(Longleaf::SystemConfigManager)
        expect(result.index_driver).to_not be_nil
      end
    end
  end
end
    