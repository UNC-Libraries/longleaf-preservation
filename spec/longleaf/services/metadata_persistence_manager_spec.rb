require 'spec_helper'
require 'longleaf/services/metadata_serializer'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'
require 'yaml'
require 'tempfile'
require 'tmpdir'

describe Longleaf::MetadataPersistenceManager do
  SysConfigBuilder ||= Longleaf::SystemConfigBuilder
  
  describe '.persist' do
    # without indexing
    # with indexing
    # without metadata record
    
    context 'minimal configuration' do
      let(:app_config_manager) { build(:application_config_manager) }
      
      # mock the indexer, verify that serializer called
      
      # with metadata record
      
      # without metadata record
    end
    
    context 'configured with metadata index' do
      let(:sys_config_path) { SysConfigBuilder.new
          .get }
    end
  end
end