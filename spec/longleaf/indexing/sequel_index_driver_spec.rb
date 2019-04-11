require 'spec_helper'
require 'longleaf/models/file_record'
require 'longleaf/errors'
require 'longleaf/indexing/sequel_index_driver'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/metadata_builder'
require 'longleaf/specs/file_helpers'
require 'longleaf/services/application_config_deserializer'
require 'fileutils'
require 'tmpdir'
require 'tempfile'
require 'sequel'

describe Longleaf::SequelIndexDriver do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  MetadataBuilder ||= Longleaf::MetadataBuilder
  
  SECONDS_IN_DAY ||= 60 * 60 * 24
  
  let(:md_dir) { Dir.mktmpdir('metadata') }
  let(:path_dir) { Dir.mktmpdir('path') }

  after do
    FileUtils.remove_dir(md_dir)
    FileUtils.remove_dir(path_dir)
    FileUtils.rm('tmp/test.db')
  end
  
  let(:config_path) { ConfigBuilder.new
      .with_service(name: 'serv1', frequency: '1 day')
      .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
      .map_services('loc1', 'serv1')
      .write_to_yaml_file }
      
  let(:app_config) { Longleaf::ApplicationConfigDeserializer.deserialize(config_path) }
  let(:config_md5) { Digest::MD5.file(config_path).hexdigest }
  
  let(:conn_details) { 'amalgalite://tmp/test.db' }
  
  let(:driver) { Longleaf::SequelIndexDriver.new(app_config, :amalgalite, conn_details) }
  
  describe '.setup_index' do
    it 'creates database structure' do
      driver.setup_index
      
      result = db_conn[Longleaf::SequelIndexDriver::INDEX_STATE_TBL].select.first
      expect(result[:config_md5]).to eq config_md5
      
      expect(db_conn.table_exists?(Longleaf::SequelIndexDriver::PRESERVE_TBL))
    end
  end
  
  describe '.is_stale?' do
    before do
      driver.setup_index
    end
    
    context 'with new empty index' do
      it { expect(driver.is_stale?).to be false }
    end
    
    context 'with modified config file' do
      let(:config_path2) { ConfigBuilder.new
          .with_service(name: 'serv_other')
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', 'serv_other')
          .write_to_yaml_file }
      let(:app_config2) { Longleaf::ApplicationConfigDeserializer.deserialize(config_path2) }
      
      let(:driver2) { Longleaf::SequelIndexDriver.new(app_config2, :amalgalite, conn_details) }
      
      it { expect(driver2.is_stale?).to be true }
    end
  end
  
  describe '.index' do
    before do
      driver.setup_index
    end
    
    let(:storage_loc) { build(:storage_location, name: 'loc1',  path: path_dir, metadata_path: md_dir) }
    let(:file_path) { create_test_file(dir: path_dir, name: 'test_file') }
    let(:file_rec) { build(:file_record, file_path: file_path, storage_location: storage_loc) }
    
    context 'location with no services' do
      let(:config_path) { ConfigBuilder.new
          .with_services
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .with_mappings
          .write_to_yaml_file }
      
      let(:app_config) { Longleaf::ApplicationConfigDeserializer.deserialize(config_path) }
      
      before do
        MetadataBuilder.new(file_path: file_path)
            .with_service("some_serv")
            .register_to(file_rec)
      end
      
      it 'indexes with null timestamp' do
        driver.index(file_rec)
        
        expect(get_timestamp_from_index(file_rec)).to be nil
      end
    end
    
    context 'file with no previous service runs' do
      before do
        MetadataBuilder.new(file_path: file_path).register_to(file_rec)
      end
      
      it 'indexes with current timestamp' do
        driver.index(file_rec)
        
        expect(get_timestamp_from_index(file_rec)).to be_within(5).of Time.now
      end
    end
    
    context 'service which has previously run and has no frequency' do
      let(:config_path) { ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', 'serv1')
          .write_to_yaml_file }
      let(:app_config) { Longleaf::ApplicationConfigDeserializer.deserialize(config_path) }
  
      before do
        MetadataBuilder.new(file_path: file_path)
            .with_service("serv1")
            .register_to(file_rec)
      end
      
      it 'indexes with null timestamp' do
        driver.index(file_rec)
        
        expect(get_timestamp_from_index(file_rec)).to be nil
      end
    end
    
    context 'previously run service with frequency' do
      before do
        MetadataBuilder.new(file_path: file_path)
            .with_service("serv1")
            .register_to(file_rec)
      end
      
      it 'indexes with timestamp one day in the future' do
        driver.index(file_rec)
        
        expect(get_timestamp_from_index(file_rec)).to be_within(5).of (Time.now + SECONDS_IN_DAY)
      end
    end
    
    context 'service run 10 days ago, with frequency' do
      before do
        MetadataBuilder.new(file_path: file_path)
            .with_service("serv1",
                timestamp: Longleaf::ServiceDateHelper::formatted_timestamp(Time.now - SECONDS_IN_DAY * 10))
            .register_to(file_rec)
      end
      
      it 'indexes with timestamp 9 days in the past' do
        driver.index(file_rec)
        
        expect(get_timestamp_from_index(file_rec)).to be_within(5).of (Time.now - SECONDS_IN_DAY * 9)
      end
    end
    
    context 'Multiple previously run services with frequencies' do
      let(:config_path) { ConfigBuilder.new
          .with_service(name: 'serv1', frequency: '2 day')
          .with_service(name: 'serv2', frequency: '6 day')
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', ['serv1', 'serv2'])
          .write_to_yaml_file }
      
      let(:app_config) { Longleaf::ApplicationConfigDeserializer.deserialize(config_path) }
      
      before do
        MetadataBuilder.new(file_path: file_path)
            .with_service("serv1")
            .with_service("serv2")
            .register_to(file_rec)
      end
      
      it 'indexes with timestamp of the earliest service time (2 days in the future)' do
        driver.index(file_rec)
        
        expect(get_timestamp_from_index(file_rec)).to be_within(5).of (Time.now + SECONDS_IN_DAY * 2)
      end
    end
    
    context 'Multiple previously run services, one with frequency' do
      let(:config_path) { ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_service(name: 'serv2', frequency: '2 day')
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', ['serv1', 'serv2'])
          .write_to_yaml_file }
      
      let(:app_config) { Longleaf::ApplicationConfigDeserializer.deserialize(config_path) }
      
      before do
        MetadataBuilder.new(file_path: file_path)
            .with_service("serv1",
                timestamp: Longleaf::ServiceDateHelper::formatted_timestamp(Time.now - SECONDS_IN_DAY * 10))
            .with_service("serv2")
            .register_to(file_rec)
      end
      
      it 'indexes with timestamp of the earliest service time (2 days in the future)' do
        driver.index(file_rec)
        
        expect(get_timestamp_from_index(file_rec)).to be_within(5).of (Time.now + SECONDS_IN_DAY * 2)
      end
    end
  end
  
  def db_conn
    @conn = Sequel.connect(conn_details) if @conn.nil?
    @conn
  end
  
  def get_timestamp_from_index(file_rec)
    result = db_conn[Longleaf::SequelIndexDriver::PRESERVE_TBL].where(file_path: file_rec.path).select(:service_time).first
  
    result[:service_time]
  end
end