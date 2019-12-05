require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'tempfile'
require 'yaml'
require 'fileutils'

describe 'validate_config', :type => :aruba do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir) { Dir.mktmpdir('metadata') }
  let(:lib_dir) { make_test_dir(name: 'lib_dir') }
  let!(:work_script_file) { create_work_class(lib_dir, 'Preserve', 'preserve.rb') }

  after(:each) do
    FileUtils.rm_rf(lib_dir)
    FileUtils.rmdir([md_dir, path_dir])
  end

  context 'no config path' do
    before { run_command_and_stop('longleaf validate_config', fail_on_error: false) }

    it { expect(last_command_started).to have_output(/No value provided for required options '--config'/) }
  end

  context 'config path does not exist' do
    before do
      config_file = Tempfile.new('config')
      config_path = config_file.path
      config_file.delete

      run_command_and_stop("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end

    it do
      expect(last_command_started).to have_output(/file .* does not exist/)
      expect(last_command_started).to have_exit_status(1)
    end
  end

  context 'invalid storage location' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: nil, md_path: md_dir)
        .with_services
        .with_mappings
        .write_to_yaml_file
    }

    before do
      run_command_and_stop("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end

    it 'outputs invalid configuration error' do
      expect(last_command_started).to have_output(/Application configuration invalid/)
      expect(last_command_started).to have_output(
              /Storage location 'loc1' specifies invalid location 'path' property: Path must not be empty/)
      expect(last_command_started).to have_exit_status(1)
    end
  end

  context 'unavailable storage location' do
    let(:del_path_dir) { FileUtils.rmdir(Dir.mktmpdir('path'))[0] }
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: del_path_dir, md_path: md_dir)
        .with_services
        .with_mappings
        .write_to_yaml_file
    }

    before do
      run_command_and_stop("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end

    it 'outputs path does not exist configuration error' do
      expect(last_command_started).to have_output(/Application configuration invalid/)
      expect(last_command_started).to have_output(/Storage location 'loc1' specifies invalid location 'path' property: Path does not exist/)
      expect(last_command_started).to have_exit_status(1)
    end
  end

  context 'valid storage location' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_services
        .with_mappings
        .write_to_yaml_file
    }

    before do
      run_command_and_stop("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end

    it do
      expect(last_command_started).to have_output(/SUCCESS: Application configuration passed validation/)
      expect(last_command_started).to have_exit_status(0)
    end
  end

  context 'overlapping storage locations' do
    let(:md_dir2) { Dir.mktmpdir('metadata') }
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_location(name: 'loc2', path: path_dir, md_path: md_dir2)
        .with_services
        .with_mappings
        .write_to_yaml_file
    }

    before do
      run_command_and_stop("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end

    after do
      FileUtils.rmdir([md_dir2])
    end

    it 'outputs overlapping storage paths error' do
      expect(last_command_started).to have_output(/Application configuration invalid/)
      expect(last_command_started).to have_output(/which overlaps with another configured path/)
      expect(last_command_started).to have_exit_status(1)
    end
  end

  context 'invalid service definition' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: nil)
        .with_mappings
        .write_to_yaml_file
    }

    before do
      run_command_and_stop("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end

    it 'outputs missing field error' do
      expect(last_command_started).to have_output(/Application configuration invalid/)
      expect(last_command_started).to have_output(/Service definition 'serv1' must specify a 'work_script' property/)
      expect(last_command_started).to have_exit_status(1)
    end
  end

  context 'uninitializable service definition' do
    let!(:work_script_file) {
      create_work_class(lib_dir, 'Preserve', 'preserve.rb',
        init_body: 'raise ArgumentError.new("Service configuration missing option required by service class")')
    }
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: work_script_file)
        .with_mappings
        .write_to_yaml_file
    }

    before do
      run_command_and_stop("longleaf validate_config -c #{config_path} -I #{lib_dir}", fail_on_error: false)
    end

    it 'outputs missing field error' do
      expect(last_command_started).to have_output(/Application configuration invalid/)
      expect(last_command_started).to have_output(/Service configuration missing option required by service class/)
      expect(last_command_started).to have_exit_status(1)
    end
  end

  context 'valid service definition' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_locations
        .with_service(name: 'serv1', work_script: work_script_file)
        .with_mappings
        .write_to_yaml_file
    }

    context 'with -c option' do
      before do
        run_command_and_stop("longleaf validate_config -c #{config_path} -I #{lib_dir}", fail_on_error: false)
      end

      it { expect(last_command_started).to have_output(/SUCCESS: Application configuration passed validation/) }
    end

    context 'with config from environment' do
      before do
        append_environment_variable('LONGLEAF_CFG', config_path)
        run_command_and_stop("longleaf validate_config -I #{lib_dir}", fail_on_error: false)
      end

      it { expect(last_command_started).to have_output(/SUCCESS: Application configuration passed validation/) }
    end
  end

  context 'valid service mapping' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: work_script_file)
        .map_services('loc1', 'serv1')
        .write_to_yaml_file
    }

    before do
      run_command_and_stop("longleaf validate_config -c #{config_path} -I #{lib_dir}", fail_on_error: false)
    end

    it do
      expect(last_command_started).to have_output(/SUCCESS: Application configuration passed validation/)
      expect(last_command_started).to have_exit_status(0)
    end
  end

  context 'validation issues in each section' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: nil)
        .with_service(name: 'serv1', work_script: nil)
        .map_services('loc1', ['serv1', 'serv_none'])
        .write_to_yaml_file
    }

    before do
      run_command_and_stop("longleaf validate_config -c #{config_path} -I #{lib_dir}", fail_on_error: false)
    end

    it 'reports all errors' do
      expect(last_command_started).to have_output(/Application configuration invalid/)
      expect(last_command_started).to have_output(/Metadata location must be present for location 'loc1'/)
      expect(last_command_started).to have_output(/Service definition 'serv1' must specify a 'work_script' property/)
      expect(last_command_started).to have_output(/Mapping specifies value 'serv_none'/)
      expect(last_command_started).to have_exit_status(1)
    end
  end
end
