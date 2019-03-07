require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/config_builder'
require 'tempfile'
require 'yaml'
require 'fileutils'

describe 'validate_config', :type => :aruba do
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
  context 'no config path' do
    before { run_simple('longleaf validate_config', fail_on_error: false) }
    
    it { expect(last_command_started).to have_output(/No value provided for required options '--config'/) }
  end
  
  context 'config path does not exist' do
    before do 
      config_file = Tempfile.new('config')
      config_path = config_file.path
      config_file.delete
      
      run_simple("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end
    
    it do
      expect(last_command_started).to have_output(/file .* does not exist/)
      expect(last_command_started).to have_exit_status(1)
    end
  end
  
  context 'invalid storage location' do
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: nil, md_path: md_dir)
        .with_services
        .with_mappings
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end
    
    after do
      FileUtils.rmdir(md_dir)
    end
    
    it 'outputs invalid configuration error' do
      expect(last_command_started).to have_output(/Application configuration invalid/)
      expect(last_command_started).to have_output(
              /Storage location 'loc1' specifies invalid 'path' property: Path must not be empty/)
      expect(last_command_started).to have_exit_status(1)
    end
  end
  
  context 'unavailable storage location' do
    let(:path_dir) { FileUtils.rmdir(Dir.mktmpdir('path'))[0] }
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_services
        .with_mappings
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end
    
    after do
      FileUtils.rmdir(md_dir)
    end
    
    it 'outputs path does not exist configuration error' do
      expect(last_command_started).to have_output(/Application configuration invalid/)
      expect(last_command_started).to have_output(/Path does not exist or is not a directory/)
      expect(last_command_started).to have_exit_status(1)
    end
  end
  
  context 'valid storage location' do
    let(:path_dir) { Dir.mktmpdir('path') }
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_services
        .with_mappings
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end
    
    after do
      FileUtils.rmdir([md_dir, path_dir])
    end
    
    it do
      expect(last_command_started).to have_output(/SUCCESS: Application configuration passed validation/)
      expect(last_command_started).to have_exit_status(0)
    end
  end
  
  context 'overlapping storage locations' do
    let(:path_dir1) { Dir.mktmpdir('path') }
    let(:md_dir1) { Dir.mktmpdir('metadata') }
    let(:md_dir2) { Dir.mktmpdir('metadata') }
    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
        .with_location(name: 'loc2', path: path_dir1, md_path: md_dir2)
        .with_services
        .with_mappings
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end
    
    after do
      FileUtils.rmdir([md_dir1, path_dir1, md_dir2])
    end
    
    it 'outputs overlapping storage paths error' do
      expect(last_command_started).to have_output(/Application configuration invalid/)
      expect(last_command_started).to have_output(/which overlaps with another configured path/)
      expect(last_command_started).to have_exit_status(1)
    end
  end
  
  context 'invalid service definition' do
    let(:path_dir) { Dir.mktmpdir('path') }
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: nil)
        .with_mappings
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end
    
    after do
      FileUtils.rmdir([md_dir, path_dir])
    end
    
    it 'outputs missing field error' do
      expect(last_command_started).to have_output(/Application configuration invalid/)
      expect(last_command_started).to have_output(/Service definition 'serv1' must specify a 'work_script' property/)
      expect(last_command_started).to have_exit_status(1)
    end
  end
  
  context 'valid service definition' do
    let!(:config_path) { ConfigBuilder.new
        .with_locations
        .with_service(name: 'serv1', work_script: 'preserve.rb')
        .with_mappings
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end
    
    it { expect(last_command_started).to have_output(/SUCCESS: Application configuration passed validation/) }
  end
  
  context 'valid service mapping' do
    let(:path_dir) { Dir.mktmpdir('path') }
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: 'preserve.rb')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end
    
    after do
      FileUtils.rmdir([md_dir, path_dir])
    end
    
    it do
      expect(last_command_started).to have_output(/SUCCESS: Application configuration passed validation/)
      expect(last_command_started).to have_exit_status(0)
    end
  end
end