require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/config_builder'
require 'longleaf/helpers/service_date_helper'
require 'longleaf/services/metadata_serializer'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/services/application_config_deserializer'
require 'tempfile'
require 'yaml'
require 'fileutils'

describe 'metadata digests', :type => :aruba do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir) { Dir.mktmpdir('metadata') }
  let(:lib_dir) { make_test_dir(name: 'lib_dir') }
  
  let!(:work_script_file) { create_work_class(lib_dir, 'PresService', 'pres_service.rb') }
  
  after do
    FileUtils.rm_rf([md_dir, path_dir, lib_dir])
    $LOAD_PATH.delete(lib_dir)
  end
  
  context 'location with a service and metadata digest configured' do
    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir, md_digests: ['sha1'])
        .with_service(name: 'serv1', work_script: work_script_file)
        .map_services('loc1', 'serv1')
        .write_to_yaml_file }
    let(:file_path) { create_test_file(dir: path_dir) }
    
    context 'metadata file digest matches' do
      before do
        run_simple("longleaf register -c #{config_path} -f #{file_path}", fail_on_error: false)
        
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
      end
      
      it 'successfully runs' do
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path}/)
        expect(last_command_started).to have_exit_status(0)
      end
    end
    
    context 'metadata file unexpectedly changed' do
      before do
        run_simple("longleaf register -c #{config_path} -f #{file_path}", fail_on_error: false)
        
        change_metadata(file_path, config_path, timestamp: Time.now - 100)
        
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
      end
      
      it 'fails preserve event with metadata digest error' do
        expect(last_command_started).to have_output(/FAILURE preserve: Metadata digest of type sha1 did not match the contents/)
        expect(last_command_started).to have_exit_status(1)
      end
    end
  end
  
  context 'location with a service and multiple metadata digest configured' do
    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir, md_digests: ['sha1', 'sha512'])
        .with_service(name: 'serv1', work_script: work_script_file)
        .map_services('loc1', 'serv1')
        .write_to_yaml_file }
    let(:file_path) { create_test_file(dir: path_dir) }
    
    context 'metadata file digests match' do
      before do
        run_simple("longleaf register -c #{config_path} -f #{file_path}", fail_on_error: false)
        
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
      end
      
      it 'successfully runs' do
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path}/)
        expect(last_command_started).to have_exit_status(0)
      end
    end
    
    context 'sha512 digest modified' do
      before do
        run_simple("longleaf register -c #{config_path} -f #{file_path}", fail_on_error: false)
        
        change_digest(file_path, config_path, 'sha512')
        
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
      end
      
      it 'fails preserve event with sha512 digest error' do
        expect(last_command_started).to have_output(/FAILURE preserve: Metadata digest of type sha512 did not match the contents/)
        expect(last_command_started).to have_exit_status(1)
      end
    end
  end
  
  def get_metadata_path(file_path, config_path)
    app_config = Longleaf::ApplicationConfigDeserializer.deserialize(config_path)
    location = app_config.location_manager.get_location_by_path(file_path)
    location.get_metadata_path_for(file_path)
  end
  
  def change_metadata(file_path, config_path, timestamp: Time.now)
    md_path = get_metadata_path(file_path, config_path)
    # Add a newline to the metadata to change it
    File.open(md_path, 'a') do |f|
      f.write("\n")
    end
  end
  
  def change_digest(file_path, config_path, alg)
    md_path = get_metadata_path(file_path, config_path)
    digest_path = "#{md_path}.#{alg}"
    File.open(digest_path, 'a') do |f|
      f.write("bad")
    end
  end
end
  