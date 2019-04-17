require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/system_config_builder'
require 'longleaf/indexing/sequel_index_driver'
require 'tempfile'
require 'fileutils'
require 'sequel'

describe 'metadata indexing', :type => :aruba do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  SysConfigBuilder ||= Longleaf::SystemConfigBuilder
  
  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir) { Dir.mktmpdir('metadata') }
  let(:lib_dir) { make_test_dir(name: 'lib_dir') }
  
  let(:db_file) { create_test_file(name: 'index.db', content: '') }
  
  let!(:work_script_file) { create_work_class(lib_dir, 'PresService', 'pres_service.rb') }

  after do
    FileUtils.rm_rf([md_dir, path_dir, lib_dir])
    FileUtils.rm(db_file)
    $LOAD_PATH.delete(lib_dir)
  end
  
  context 'indexing to relational database enabled' do
    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: work_script_file)
        .map_services('loc1', 'serv1')
        .write_to_yaml_file }
  
    let(:sys_config_path) { SysConfigBuilder.new
        .with_index('amalgalite', "amalgalite://#{db_file}")
        .write_to_yaml_file }
  
    # Initialize the index's database
    before do
      run_simple("longleaf setup_index -c #{config_path} -y #{sys_config_path}", fail_on_error: false)
      expect(last_command_started).to have_exit_status(0)
    end
    
    let(:file_path) { create_test_file(dir: path_dir) }
    
    context 'registering a file' do
      before do
        run_simple("longleaf register -c #{config_path} -f #{file_path} -y #{sys_config_path}", fail_on_error: false)
      end
      
      it 'successfully runs and adds entry to index' do
        expect(last_command_started).to have_exit_status(0)
        
        expect(get_timestamp_from_index(file_path)).to be_within(60).of (Time.now)
      end
    end
    
    context 'reregistering a file' do
      before do
        run_simple("longleaf register -c #{config_path} -f #{file_path} -y #{sys_config_path}", fail_on_error: false)
        @first_timestamp = get_timestamp_from_index(file_path)
        run_simple("longleaf register -c #{config_path} -f #{file_path} -y #{sys_config_path} --force", fail_on_error: false)
      end
    
      it 'successfully runs and updates entry in index' do
        # The timestamp is updated because the file's only service has never run
        expect(last_command_started).to have_exit_status(0)
        second_timestamp = get_timestamp_from_index(file_path)
        expect(second_timestamp).to_not eq @first_timestamp
        expect(second_timestamp).to be_within(60).of (Time.now)
      end
    end
    
    context 'performing preserve event on registered file with single run service' do
      before do
        run_simple("longleaf register -c #{config_path} -f #{file_path} -y #{sys_config_path}", fail_on_error: false)
        @first_timestamp = get_timestamp_from_index(file_path)
        run_simple("longleaf preserve -c #{config_path} -f #{file_path} -y #{sys_config_path} -I #{lib_dir}", fail_on_error: false)
      end
    
      it 'successfully runs and updates entry in index with nil timestamp' do
        # The timestamp should go to nil since the only service is set to run once
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path}/)
        expect(last_command_started).to have_exit_status(0)
        second_timestamp = get_timestamp_from_index(file_path)
        expect(second_timestamp).to_not eq @first_timestamp
        expect(second_timestamp).to be_nil
      end
    end
    
    # TODO: verify indexing after deregister once deregister indexing behavior implemented
  end
  
  def db_conn
    @conn = Sequel.connect("amalgalite://#{db_file}") if @conn.nil?
    @conn
  end
  
  def get_timestamp_from_index(file_path)
    result = db_conn[Longleaf::SequelIndexDriver::PRESERVE_TBL].where(file_path: file_path).select(:service_time).first
  
    result[:service_time]
  end
end