require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/config_builder'
require 'longleaf/services/metadata_serializer'
require 'longleaf/specs/file_helpers'
require 'tempfile'
require 'yaml'
require 'fileutils'

describe 'register', :type => :aruba do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir) { Dir.mktmpdir('metadata') }

  after do
    FileUtils.remove_dir(md_dir)
    FileUtils.remove_dir(path_dir)
  end

  context 'config path does not exist' do
    before do
      config_file = Tempfile.new('config')
      config_path = config_file.path
      config_file.delete

      run_command_and_stop("longleaf register -c #{config_path} -f '/path/to/file'", fail_on_error: false)
    end

    it 'outputs error loading configuration' do
      expect(last_command_started).to have_output(/Failed to load application configuration/)
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
      run_command_and_stop("longleaf register -c #{config_path} -f '/path/to/file'", fail_on_error: false)
    end

    it 'outputs invalid configuration error' do
      expect(last_command_started).to have_output(/Failed to load application configuration/)
      expect(last_command_started).to have_output(
              /Storage location 'loc1' specifies invalid 'path' property: Path must not be empty/)
      expect(last_command_started).to have_exit_status(1)
    end
  end

  context 'with valid configuration' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file
    }
    let!(:file_path) { create_test_file(dir: path_dir) }

    context 'empty file path' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f ''", fail_on_error: false)
      end

      it 'rejects missing file path value' do
        expect(last_command_started).to have_output(/Must provide either file paths or storage locations/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'file does not exist' do
      before do
        File.delete(file_path)

        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'rejects file which does not exist' do
        expect(last_command_started).to have_output(
          /FAILURE register: File .* does not exist./)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'file not in a registered storage location' do
      before do
        test_file = Tempfile.new('not_in_loc')
        out_of_location = test_file.path

        run_command_and_stop("longleaf register -c #{config_path} -f '#{out_of_location}'", fail_on_error: false)
      end

      it 'outputs failure to find storage location' do
        expect(last_command_started).to have_output(
          /FAILURE register: Path .* is not from a known storage location/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'register file' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'registers the file' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect(metadata_created(file_path, md_dir)).to be true
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register file more than once' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end
      it 'rejects registering file' do
        # File should be registered by first call
        expect(metadata_created(file_path, md_dir)).to be true
        # Only testing output from second command, so no registered message visible
        expect(last_command_started).to_not have_output(/SUCCESS.*/)
        expect(last_command_started).to have_output(
            /Unable to register '#{file_path}', it is already registered/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'register file more than once with force flag' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}' --force", fail_on_error: false)
      end
      it 'registers the file' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect(metadata_created(file_path, md_dir)).to be true
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register multiple files' do
      let(:file_path2) { create_test_file(dir: path_dir, name: 'another_file', content: 'more content') }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path},#{file_path2}'")
      end

      it 'registers both files' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect(metadata_created(file_path, md_dir)).to be true
        expect(last_command_started).to have_output(/SUCCESS register #{file_path2}/)
        expect(metadata_created(file_path2, md_dir)).to be true
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register multiple files by storage location' do
      let!(:file_path2) { create_test_file(dir: path_dir, name: 'another_file', content: 'more content') }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -s 'loc1' --log-level 'DEBUG'")
      end

      it 'registers both files' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect(metadata_created(file_path, md_dir)).to be true
        expect(last_command_started).to have_output(/SUCCESS register #{file_path2}/)
        expect(metadata_created(file_path2, md_dir)).to be true
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register directory of files' do
      let!(:file_path2) { create_test_file(dir: path_dir, name: 'another_file', content: 'more content') }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{path_dir}/' --log_level DEBUG", fail_on_error: false)
      end

      it 'registers both files' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect(metadata_created(file_path, md_dir)).to be true
        expect(last_command_started).to have_output(/SUCCESS register #{file_path2}/)
        expect(metadata_created(file_path2, md_dir)).to be true
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'invalid checksum format' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}' --checksums 'flat'", fail_on_error: false)
      end

      it 'rejects checksum parameter' do
        expect(last_command_started).to have_output(/Invalid checksums parameter format/)
        expect(metadata_created(file_path, md_dir)).to be false
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'valid checksum format' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}' --checksums 'md5:digest'")
      end

      it 'registers the file' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect(metadata_created(file_path, md_dir)).to be true
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'multiple valid checksums' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}' --checksums 'md5:digest,sha1:anotherdigest'")
      end

      it 'registers the file' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect(metadata_created(file_path, md_dir)).to be true
        expect(last_command_started).to have_exit_status(0)
      end
    end
  end

  def metadata_created(file_path, md_dir)
    metadata_path = File.join(md_dir, File.basename(file_path) + Longleaf::MetadataSerializer::metadata_suffix)
    File.exist?(metadata_path)
  end
end
