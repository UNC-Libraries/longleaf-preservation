require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/config_builder'
require 'tempfile'
require 'yaml'
require 'fileutils'

describe 'fixity check service', :type => :aruba do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir) { Dir.mktmpdir('metadata') }

  let(:file_path) { create_test_file(dir: path_dir, content: 'check me') }

  after do
    FileUtils.rm_rf([md_dir, path_dir])
  end

  context 'valid service config' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1',
            work_script: 'file_check_service',
            frequency: '1 minute')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file
    }

    context 'validating configuration' do
      before do
        run_command_and_stop("longleaf validate_config -c #{config_path}", fail_on_error: false)
      end

      it 'exits with failure' do
        expect(last_command_started).to have_output(/Application configuration passed validation/)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'preserving registered file' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f #{file_path}", fail_on_error: false)

        run_command_and_stop("longleaf preserve -c #{config_path} -f #{file_path}", fail_on_error: false)
      end

      it 'successfully runs service' do
        expect(last_command_started).to have_output(%r"SUCCESS preserve\[serv1\] #{file_path}")
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'preserving file that has been modified' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f #{file_path}", fail_on_error: false)

        File.open(file_path, 'w') do |file|
          file << 'check_me'
        end

        run_command_and_stop("longleaf preserve -c #{config_path} -f #{file_path}", fail_on_error: false)
      end

      it 'successfully runs service' do
        expect(last_command_started).to have_output(%r"FAILURE preserve\[serv1\] #{file_path}: Last modified timestamp for #{file_path} does not match the expected value")
        expect(last_command_started).to have_exit_status(1)
      end
    end
  end
end
