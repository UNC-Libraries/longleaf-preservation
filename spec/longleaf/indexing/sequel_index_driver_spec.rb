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
require 'date'

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
    
    context 'location with no services' do
      let(:config_path) { ConfigBuilder.new
          .with_services
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .with_mappings
          .write_to_yaml_file }
      
      let(:app_config) { Longleaf::ApplicationConfigDeserializer.deserialize(config_path) }
      
      let!(:file_rec1) { create_index_file_rec(storage_loc, "some_serv", Time.now) }
      
      it 'indexes with null timestamp' do
        driver.index(file_rec1)
        
        expect(get_timestamp_from_index(file_rec1)).to be nil
      end
    end
    
    context 'file with no previous service runs' do
      let!(:file_rec1) { create_index_file_rec(storage_loc) }
      
      it 'indexes with current timestamp' do
        driver.index(file_rec1)
        
        expect(get_timestamp_from_index(file_rec1)).to be_within(5).of Time.now
      end
    end
    
    context 'service which has previously run and has no frequency' do
      let(:config_path) { ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', 'serv1')
          .write_to_yaml_file }
      let(:app_config) { Longleaf::ApplicationConfigDeserializer.deserialize(config_path) }
  
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", Time.now) }
      
      it 'indexes with null timestamp' do
        driver.index(file_rec1)
        
        expect(get_timestamp_from_index(file_rec1)).to be nil
      end
    end
    
    context 'previously run service with frequency' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", Time.now) }
      
      it 'indexes with timestamp one day in the future' do
        driver.index(file_rec1)
        
        expect(get_timestamp_from_index(file_rec1)).to be_within(5).of (Time.now + SECONDS_IN_DAY)
      end
    end
    
    context 'service run 10 days ago, with frequency' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", Time.now.utc - SECONDS_IN_DAY * 10) }
      
      it 'indexes with timestamp 9 days in the past' do
        driver.index(file_rec1)
        
        expect(get_timestamp_from_index(file_rec1)).to be_within(5).of (Time.now - SECONDS_IN_DAY * 9)
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
      
      let(:file_path) { create_test_file(dir: path_dir) }
      let(:file_rec) { build(:file_record, file_path: file_path, storage_location: storage_loc) }
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
      
      let(:file_path) { create_test_file(dir: path_dir) }
      let(:file_rec) { build(:file_record, file_path: file_path, storage_location: storage_loc) }
      before do
        MetadataBuilder.new(file_path: file_path)
            .with_service("serv1",
                timestamp: Time.now - SECONDS_IN_DAY * 10)
            .with_service("serv2")
            .register_to(file_rec)
      end
      
      it 'indexes with timestamp of the earliest service time (2 days in the future)' do
        driver.index(file_rec)
        
        expect(get_timestamp_from_index(file_rec)).to be_within(5).of (Time.now + SECONDS_IN_DAY * 2)
      end
    end
    
    context 'deregistered file' do
      let(:file_path) { create_test_file(dir: path_dir) }
      let(:file_rec) { build(:file_record, file_path: file_path, storage_location: storage_loc) }
      before do
        MetadataBuilder.new(file_path: file_path)
            .with_service("serv1")
            .deregistered
            .register_to(file_rec)
      end
      
      it 'indexes with null timestamp' do
        driver.index(file_rec)
        
        expect(get_timestamp_from_index(file_rec)).to be nil
      end
    end
  end
  
  describe '.paths_with_stale_services' do
    before do
      driver.setup_index
    end
    
    let(:storage_loc) { build(:storage_location, name: 'loc1',  path: path_dir, metadata_path: md_dir) }
    
    context 'no file paths registered' do
      let(:selector) { build(:file_selector,
              storage_locations: ['loc1'],
              app_config: app_config) }
      
      it 'returns no file paths' do
        results = driver.paths_with_stale_services(selector, Time.now.utc)
        expect(results).to be_empty
      end
    end
    
    context 'no file paths with services needed' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", Time.now.utc + SECONDS_IN_DAY * 2) }
      
      let(:selector) { build(:file_selector,
              storage_locations: ['loc1'],
              app_config: app_config) }
      
      it 'returns no file paths' do
        results = driver.paths_with_stale_services(selector, Time.now.utc)
        expect(results).to be_empty
      end
    end
    
    context 'one file path needing services' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1") }
      
      context 'file selector for storage location' do
        let(:selector) { build(:file_selector, 
                storage_locations: ['loc1'],
                app_config: app_config) }
        
        it 'returns the file needing services' do
          results = driver.paths_with_stale_services(selector, Time.now.utc + SECONDS_IN_DAY * 2)
          expect(results).to contain_exactly(file_rec1.path)
        end
      end
    end
    
    context 'multiple files needing services' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", Time.now.utc - SECONDS_IN_DAY * 2) }
      let!(:file_rec2) { create_index_file_rec(storage_loc, "serv1", Time.now.utc - SECONDS_IN_DAY * 10) }
      
      context 'file selector for exact path' do
        let(:selector) { build(:file_selector,
                file_paths: [file_rec1.path],
                app_config: app_config) }
        
        it 'returns the matching file path' do
          results = driver.paths_with_stale_services(selector, Time.now.utc)
          expect(results).to eq [file_rec1.path]
        end
      end
      
      context 'file selector for directory path' do
        let(:selector) { build(:file_selector,
                file_paths: [path_dir],
                app_config: app_config) }
        
        it 'returns two file paths, with path2 first since its services are more stale' do
          results = driver.paths_with_stale_services(selector, Time.now.utc)
          expect(results).to eq [file_rec2.path, file_rec1.path]
        end
      end
      
      context 'file selector for storage location path' do
        let(:selector) { build(:file_selector,
                storage_locations: ['loc1'],
                app_config: app_config) }
        
        it 'returns two file paths, with path2 first since its services are more stale' do
          results = driver.paths_with_stale_services(selector, Time.now.utc)
          expect(results).to eq [file_rec2.path, file_rec1.path]
        end
      end
      
      context 'file selector for empty path' do
        let(:sub_dir) { FileUtils.mkdir(File.join(path_dir, 'sub_dir'))[0] }
        
        let(:selector) { build(:file_selector,
                file_paths: [sub_dir],
                app_config: app_config) }
        
        it 'returns no file paths' do
          results = driver.paths_with_stale_services(selector, Time.now.utc)
          expect(results).to be_empty
        end
      end
    end
    
    context 'multiple files with no services needed' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", Time.now.utc + SECONDS_IN_DAY * 2) }
      let!(:file_rec2) { create_index_file_rec(storage_loc, "serv1", Time.now.utc + SECONDS_IN_DAY) }
      
      let(:selector) { build(:file_selector,
              storage_locations: ['loc1'],
              app_config: app_config) }
              
      it 'returns no file paths' do
        results = driver.paths_with_stale_services(selector, Time.now.utc)
        expect(results).to be_empty
      end
    end
    
    context 'driver with page size set to 2' do
      let(:driver) { Longleaf::SequelIndexDriver.new(app_config, :amalgalite, conn_details, page_size: 2) }
      
      context 'three files which need services' do
        let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", Time.now.utc - SECONDS_IN_DAY * 2) }
        let!(:file_rec2) { create_index_file_rec(storage_loc, "serv1", Time.now.utc - SECONDS_IN_DAY * 10) }
        let!(:file_rec3) { create_index_file_rec(storage_loc, "serv1", Time.now.utc - SECONDS_IN_DAY * 8) }
      
        let(:selector) { build(:file_selector,
                storage_locations: ['loc1'],
                app_config: app_config) }
              
        it 'returns only the first two results, ordered by staleness' do
          results = driver.paths_with_stale_services(selector, Time.now.utc)
          expect(results).to eq [file_rec2.path, file_rec3.path]
        end
      end
    end
  end
  
  describe '.registered_paths' do
    before do
      driver.setup_index
    end
    
    let(:storage_loc) { build(:storage_location, name: 'loc1',  path: path_dir, metadata_path: md_dir) }
    
    context 'no file paths registered' do
      let(:selector) { build(:file_selector,
              storage_locations: ['loc1'],
              app_config: app_config) }
      
      it 'returns no file paths' do
        results = driver.registered_paths(selector)
        expect(results).to be_empty
      end
    end
    
    context 'multiple registered, needing services and not needing services' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", Time.now.utc - SECONDS_IN_DAY * 2) }
      let!(:file_rec2) { create_index_file_rec(storage_loc, "serv1", Time.now.utc + SECONDS_IN_DAY * 10) }
      
      context 'file selector for exact path' do
        let(:selector) { build(:file_selector,
                file_paths: [file_rec1.path],
                app_config: app_config) }
        
        it 'returns the matching file path' do
          results = driver.registered_paths(selector)
          expect(results).to containing_exactly(file_rec1.path)
        end
      end
      
      context 'file selector for storage location path' do
        let(:selector) { build(:file_selector,
                storage_locations: ['loc1'],
                app_config: app_config) }
        
        it 'returns both file paths' do
          results = driver.registered_paths(selector)
          expect(results).to containing_exactly(file_rec1.path, file_rec2.path)
        end
        
        context 'with page size of 1' do
          let(:driver) { Longleaf::SequelIndexDriver.new(app_config, :amalgalite, conn_details, page_size: 1) }
        
          it 'returns the matching file path' do
            results = driver.registered_paths(selector)
            expect(results).to containing_exactly(file_rec1.path)
          end
        end
      end
    end
  end
  
  def db_conn
    @conn = Sequel.connect(conn_details) if @conn.nil?
    @conn
  end
  
  def get_timestamp_from_index(file_rec)
    result = db_conn[Longleaf::SequelIndexDriver::PRESERVE_TBL].where(file_path: file_rec.path).select(:service_time).first
  
    result.nil? ? nil : result[:service_time]
  end
  
  def create_index_file_rec(storage_loc, with_service = nil, with_timestamp = nil)
    file_path = create_test_file(dir: storage_loc.path)
    file_rec = build(:file_record, file_path: file_path, storage_location: storage_loc)
    
    md_builder = MetadataBuilder.new(file_path: file_path)
    unless with_service.nil?
      md_builder.with_service(with_service, timestamp: with_timestamp)
    end
    md_builder.register_to(file_rec)
    
    driver.index(file_rec)
    file_rec
  end
end