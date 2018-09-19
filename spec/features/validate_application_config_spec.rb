require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/config_builder'
require 'tempfile'
require 'yaml'
require 'fileutils'

describe 'validate_config', :type => :aruba do
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
  context 'no config path' do
    before { run_simple('longleaf validate_config') }
    
    it { expect(last_command_started).to have_output(/was called with no arguments/) }
  end
  
  context 'config path does not exist' do
    before do 
      config_file = Tempfile.new('config')
      config_path = config_file.path
      config_file.delete
      
      run_simple("longleaf validate_config #{config_path}")
    end
    
    it { expect(last_command_started).to have_output(/file .* does not exist/) }
  end
  
  context 'invalid storage location' do
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let(:config_path) { ConfigBuilder.new
        .with_locations
        .with_location(name: 'loc1', path: nil, md_path: md_dir)
        .with_services
        .with_mappings({})
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config #{config_path}")
    end
    
    after do
      FileUtils.rmdir(md_dir)
    end
    
    it { expect(last_command_started).to have_output(/Application configuration invalid/) }
    it { expect(last_command_started).to have_output(/Storage location 'loc1' must specify a 'path' property/) }
  end
  
  context 'valid storage location' do
    let(:path_dir) { Dir.mktmpdir('path') }
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let(:config_path) { ConfigBuilder.new
        .with_locations
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_services
        .with_mappings({})
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config #{config_path}")
    end
    
    after do
      FileUtils.rmdir([md_dir, path_dir])
    end
    
    it { expect(last_command_started).to have_output(/Success, application configuration passed validation/) }
  end
  
  context 'overlapping storage locations' do
    let(:path_dir1) { Dir.mktmpdir('path') }
    let(:md_dir1) { Dir.mktmpdir('metadata') }
    let(:md_dir2) { Dir.mktmpdir('metadata') }
    let(:config_path) { ConfigBuilder.new
        .with_locations
        .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
        .with_location(name: 'loc2', path: path_dir1, md_path: md_dir2)
        .with_services
        .with_mappings({})
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config #{config_path}")
    end
    
    after do
      FileUtils.rmdir([md_dir1, path_dir1, md_dir2])
    end
    
    it { expect(last_command_started).to have_output(/Application configuration invalid/) }
    it { expect(last_command_started).to have_output(/which overlaps with another configured path/) }
  end
  
  context 'invalid service definition' do
    let(:path_dir) { Dir.mktmpdir('path') }
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let(:config_path) { ConfigBuilder.new
        .with_locations
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_services
        .with_service(name: 'serv1', work_script: nil)
        .with_mappings({})
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config #{config_path}")
    end
    
    after do
      FileUtils.rmdir([md_dir, path_dir])
    end
    
    it { expect(last_command_started).to have_output(/Application configuration invalid/) }
    it { expect(last_command_started).to have_output(/Service definition 'serv1' must specify a 'work_script' property/) }
  end
  
  context 'valid service definition' do
    let(:config_path) { ConfigBuilder.new
        .with_locations
        .with_services
        .with_service(name: 'serv1', work_script: 'preserve.rb')
        .with_mappings({})
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config #{config_path}")
    end
    
    it { expect(last_command_started).to have_output(/Success, application configuration passed validation/) }
  end
  
  context 'valid service mapping' do
    let(:path_dir) { Dir.mktmpdir('path') }
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let(:config_path) { ConfigBuilder.new
        .with_locations
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_services
        .with_service(name: 'serv1', work_script: 'preserve.rb')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file }
    
    before do
      run_simple("longleaf validate_config #{config_path}")
    end
    
    after do
      FileUtils.rmdir([md_dir, path_dir])
    end
    
    it { expect(last_command_started).to have_output(/Success, application configuration passed validation/) }
  end
end