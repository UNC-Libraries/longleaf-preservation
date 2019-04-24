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

  before :all do
    Sequel.default_timezone = :utc
  end

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
        
        expect(get_timestamp_from_index(file_path)).to be_within(60).of (Time.now.utc)
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
        expect(second_timestamp).to be_within(60).of (Time.now.utc)
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
    
    context 'performing preserve event on multiple files, where the first file fails services' do
      let(:file_path2) { create_test_file(dir: path_dir) }
      
      let!(:work_script_file) { create_work_class(lib_dir, 'PresService', 'pres_service.rb',
          perform: "raise Longleaf::PreservationServiceError.new if file_rec.path == '#{file_path}'") }
      
      before do
        run_simple("longleaf register -c #{config_path} -f #{file_path} -y #{sys_config_path}", fail_on_error: false)
        run_simple("longleaf register -c #{config_path} -f #{file_path2} -y #{sys_config_path}", fail_on_error: false)
        @first_timestamp1 = get_timestamp_from_index(file_path)
        @first_timestamp2 = get_timestamp_from_index(file_path2)
        run_simple("longleaf preserve -c #{config_path} -s loc1 -y #{sys_config_path} -I #{lib_dir}", fail_on_error: false)
      end
    
      it 'partially successfully runs, setting delay on the failed file but not the other' do
        # The timestamp should go to nil since the only service is set to run once
        expect(last_command_started).to have_output(/FAILURE preserve\[serv1\] #{file_path}/)
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path2}/)
        expect(last_command_started).to have_exit_status(2)
        row1 = get_row_from_index(file_path)
        expect(row1[:service_time]).to_not eq @first_timestamp1
        expect(row1[:delay_until_time]).to be_within(60).of (Time.now.utc)
        row2 = get_row_from_index(file_path2)
        expect(row2[:service_time]).to_not eq @first_timestamp2
        expect(row2[:delay_until_time]).to_not be_within(60).of (Time.now.utc)
      end
    end
    
    context 'deregistering a file' do
      before do
        run_simple("longleaf register -c #{config_path} -f #{file_path} -y #{sys_config_path}", fail_on_error: false)
        run_simple("longleaf deregister -c #{config_path} -f #{file_path} -y #{sys_config_path}", fail_on_error: false)
      end
    
      it 'successfully runs and updates entry in index with nil timestamp' do
        expect(last_command_started).to have_exit_status(0)
        expect(get_timestamp_from_index(file_path)).to be_nil
      end
    end
  end
  
  def db_conn
    @conn = Sequel.connect("amalgalite://#{db_file}") if @conn.nil?
    @conn
  end
  
  def get_timestamp_from_index(file_path)
    get_row_from_index(file_path)[:service_time]
  end
  
  def get_row_from_index(file_path)
    db_conn[Longleaf::SequelIndexDriver::PRESERVE_TBL].where(file_path: file_path).select.first
  end
end