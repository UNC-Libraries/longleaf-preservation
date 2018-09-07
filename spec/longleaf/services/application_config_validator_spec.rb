require 'spec_helper'
require 'longleaf/services/application_config_validator'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'
require 'fileutils'

describe Longleaf::ApplicationConfigValidator do
  AppValidator ||= Longleaf::ApplicationConfigValidator
  
  describe '#validate_storage_locations' do
    context 'invalid location configuration' do
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: nil, md_path: md_dir).get }

      it { expect { AppValidator::validate_storage_locations(config) }.to raise_error(Longleaf::ConfigurationError) }
    end
    
    context 'invalid location configuration' do
      # Ensuring that path_dir does not exist
      let(:path_dir) { FileUtils.rmdir(Dir.mktmpdir('path'))[0] }
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:config) { ConfigBuilder.new.with_locations
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir).get }
      
      after(:each) do
        FileUtils.rmdir([path_dir, md_dir])
      end

      it { expect { AppValidator::validate_storage_locations(config) }.to raise_error(Longleaf::StorageLocationUnavailableError) }
    end
  end
  
end