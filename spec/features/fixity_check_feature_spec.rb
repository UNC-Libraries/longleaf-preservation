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

describe 'fixity check service', :type => :aruba do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir) { Dir.mktmpdir('metadata') }

  MD5_DIGEST ||= 'f11c72a98bf0b6e31f0b0af786a43ba7'

  let(:file_path) { create_test_file(dir: path_dir, content: 'checksum me') }

  after do
    FileUtils.rm_rf([md_dir, path_dir])
  end

  context 'service config missing required algorithm parameters' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1',
            work_script: 'fixity_check_service',
            frequency: '1 minute',
            properties: make_service_def([]))
        .map_services('loc1', 'serv1')
        .write_to_yaml_file
    }

    before do
      run_command_and_stop("longleaf validate_config -c #{config_path}", fail_on_error: false)
    end

    it 'exits with failure' do
      expect(last_command_started).to have_output(/FixityCheckService from definition serv1 requires a list of one or more digest algorithms/)
      expect(last_command_started).to have_exit_status(1)
    end
  end

  context 'valid service config' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1',
            work_script: 'fixity_check_service',
            frequency: '1 minute',
            properties: make_service_def(['md5']))
        .map_services('loc1', 'serv1')
        .write_to_yaml_file
    }

    context 'validating configuration' do
      before do
        run_command_and_stop("longleaf validate_config -c #{config_path}", fail_on_error: false)
      end

      it 'exits with success' do
        expect(last_command_started).to have_output(/Application configuration passed validation/)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'preserving with valid checksum' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f #{file_path} --checksums 'md5: #{MD5_DIGEST}'", fail_on_error: false)

        run_command_and_stop("longleaf preserve -c #{config_path} -f #{file_path}", fail_on_error: false)
      end

      it 'successfully runs service' do
        expect(last_command_started).to have_output(%r"SUCCESS preserve\[serv1\] #{file_path}")
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'preserving with invalid checksum' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f #{file_path} --checksums 'md5: 11111'", fail_on_error: false)

        run_command_and_stop("longleaf preserve -c #{config_path} -f #{file_path}", fail_on_error: false)
      end

      it 'reports failure' do
        expect(last_command_started).to have_output(%r"FAILURE preserve\[serv1\] #{file_path}")
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'preserving with multiple files' do
      let(:file_path2) { create_test_file(dir: path_dir, name: 'file2', content: 'more checksums') }
      let(:file_path3) { create_test_file(dir: path_dir, name: 'file3', content: 'fail time') }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -f #{file_path} --checksums 'md5: #{MD5_DIGEST}'", fail_on_error: false)
        run_command_and_stop("longleaf register -c #{config_path} -f #{file_path2} --checksums 'md5: 6253b590b56b50345fc14390249b6586'", fail_on_error: false)
        run_command_and_stop("longleaf register -c #{config_path} -f #{file_path3} --checksums 'md5: 11111'", fail_on_error: false)

        run_command_and_stop("longleaf preserve -c #{config_path} -s loc1", fail_on_error: false)
      end

      it 'reports two successes and a failure' do
        expect(last_command_started).to have_output(%r"SUCCESS preserve\[serv1\] #{file_path}")
        expect(last_command_started).to have_output(%r"SUCCESS preserve\[serv1\] #{file_path2}")
        expect(last_command_started).to have_output(%r"FAILURE preserve\[serv1\] #{file_path3}")
        expect(last_command_started).to have_exit_status(2)
      end
    end
    
    context 'preserving registered file with separate physical path' do
      let!(:logical_path) { File.join(path_dir, "logical") }

      before do
        run_command_and_stop(
            "longleaf register -c #{config_path} -f #{logical_path} -p #{file_path} --checksums 'md5: #{MD5_DIGEST}'",
            fail_on_error: false)
      end
      
      context 'preserving with valid checksum' do
        before do
          run_command_and_stop("longleaf preserve -c #{config_path} -f #{logical_path}", fail_on_error: false)
        end

        it 'successfully runs service' do
          expect(last_command_started).to have_output(%r"SUCCESS preserve\[serv1\] #{logical_path}")
          expect(last_command_started).to have_exit_status(0)
        end
      end
      
      context 'preserving with invalid checksum' do
        before do
          File.open(file_path, 'w') do |file|
            file << 'check_me'
          end
          run_command_and_stop("longleaf preserve -c #{config_path} -f #{logical_path}", fail_on_error: false)
        end

        it 'successfully runs service' do
          expect(last_command_started).to have_output(%r"FAILURE preserve\[serv1\] #{logical_path}: Fixity check using algorithm 'md5' failed")
          expect(last_command_started).to have_exit_status(1)
        end
      end
    end
  end

  def make_service_def(digest_algs, absent_digest: nil)
    properties = Hash.new
    properties[Longleaf::ServiceFields::DIGEST_ALGORITHMS] = digest_algs unless digest_algs.nil?
    properties[Longleaf::FixityCheckService::ABSENT_DIGEST_PROPERTY] = absent_digest unless absent_digest.nil?
    properties
  end
end
