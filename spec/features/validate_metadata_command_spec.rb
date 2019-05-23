require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/config_builder'
require 'longleaf/services/metadata_serializer'
require 'longleaf/specs/file_helpers'
require 'fileutils'

describe 'validate_metadata', :type => :aruba do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir) { Dir.mktmpdir('metadata') }
  let!(:file_path) { create_test_file(dir: path_dir) }

  after do
    FileUtils.remove_dir(md_dir)
    FileUtils.remove_dir(path_dir)
  end

  context 'location with one digest configured' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir, md_digests: ['sha1'])
        .with_service(name: 'serv1')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file
    }

    context 'file does not exist' do
      before do
        File.delete(file_path)

        run_command_and_stop("longleaf validate_metadata -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'rejects file which does not exist' do
        expect(last_command_started).to have_output(
          /FAILURE: File .* does not exist./)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'file not registered' do
      before do
        run_command_and_stop("longleaf validate_metadata -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'outputs failure to find storage location' do
        expect(last_command_started).to have_output(
          /FAILURE: File #{file_path} is not registered/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'file with no digest' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        File.delete(get_digest_path(file_path, md_dir, 'sha1'))
        run_command_and_stop("longleaf validate_metadata -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'passes validation but gives warning' do
        expect(last_command_started).to have_output(/SUCCESS: Metadata for file passed validation: #{file_path}/)
        expect(last_command_started).to have_output(/Missing expected sha1 digest for .*/)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'file with digest' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        run_command_and_stop("longleaf validate_metadata -c #{config_path} -f '#{file_path}' --log_level INFO", fail_on_error: false)
      end

      it 'passes validation without warnings' do
        expect(last_command_started).to have_output(/SUCCESS: Metadata for file passed validation: #{file_path}/)
        expect(last_command_started).to have_output(/Metadata fixity check using algorithm 'sha1' succeeded for file .*/)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'file with checksum mismatch' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        change_metadata(file_path, md_dir)
        run_command_and_stop("longleaf validate_metadata -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'passes validation but gives warning' do
        expect(last_command_started).to have_output(/FAILURE: Metadata digest of type sha1 did not match the contents of .*/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'multiple files, one has mismatch' do
      let!(:file_path2) { create_test_file(dir: path_dir, name: "file2") }
      let!(:file_path3) { create_test_file(dir: path_dir, name: "file3") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -f #{path_dir}/", fail_on_error: false)
        change_metadata(file_path2, md_dir)
        run_command_and_stop("longleaf validate_metadata -c #{config_path} -s loc1", fail_on_error: false)
      end

      it 'two pass, one fails validation' do
        expect(last_command_started).to have_output(/SUCCESS: Metadata for file passed validation: #{file_path}/)
        expect(last_command_started).to have_output(/SUCCESS: Metadata for file passed validation: #{file_path3}/)
        expect(last_command_started).to_not have_output(/SUCCESS: Metadata for file passed validation: #{file_path2}/)
        expect(last_command_started).to have_output(/FAILURE: Metadata digest of type sha1 did not match the contents of #{get_metadata_path(file_path2, md_dir)}/)
        expect(last_command_started).to have_exit_status(2)
      end
    end
  end

  context 'location with no digests configured' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file
    }

    context 'file with digest' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        # Create a digest file, contents shouldn't matter
        change_digest(file_path, md_dir, 'sha1')
        run_command_and_stop("longleaf validate_metadata -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'passes validation' do
        expect(last_command_started).to have_output(/SUCCESS: Metadata for file passed validation: #{file_path}/)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'file without digest' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        run_command_and_stop("longleaf validate_metadata -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'passes validation' do
        expect(last_command_started).to have_output(/SUCCESS: Metadata for file passed validation: #{file_path}/)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'metadata file is not valid yaml' do
      before do
        change_metadata(file_path, md_dir, "this file is garbage")
        run_command_and_stop("longleaf validate_metadata -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'fails validation' do
        expect(last_command_started).to have_output(/FAILURE: Invalid metadata file, did not contain data or services fields: #{md_dir}.*/)
        expect(last_command_started).to have_exit_status(1)
      end
    end
  end

  context 'location with multiple digests configured' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir, md_digests: ['sha1', 'sha512'])
        .with_service(name: 'serv1')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file
    }

    context 'file with all digests' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        run_command_and_stop("longleaf validate_metadata -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'passes validation' do
        expect(last_command_started).to have_output(/SUCCESS: Metadata for file passed validation: #{file_path}/)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'file with one missing digest' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        File.delete(get_digest_path(file_path, md_dir, 'sha1'))
        run_command_and_stop("longleaf validate_metadata -c #{config_path} -f '#{file_path}' --log_level INFO", fail_on_error: false)
      end

      it 'passes validation with warning' do
        expect(last_command_started).to have_output(/SUCCESS: Metadata for file passed validation: #{file_path}/)
        expect(last_command_started).to have_output(/Missing expected sha1 digest for .*/)
        expect(last_command_started).to have_output(/Metadata fixity check using algorithm 'sha512' succeeded for file .*/)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'file with one valid digest, one invalid' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        change_digest(file_path, md_dir, 'sha512')
        run_command_and_stop("longleaf validate_metadata -c #{config_path} -f '#{file_path}' --log_level INFO", fail_on_error: false)
      end

      it 'fails validation, reporting on the changed digest' do
        expect(last_command_started).to have_output(/FAILURE: Metadata digest of type sha512 did not match the contents of .*/)
        expect(last_command_started).to have_exit_status(1)
      end
    end
  end

  def get_metadata_path(file_path, md_dir)
    File.join(md_dir, File.basename(file_path) + Longleaf::MetadataSerializer::metadata_suffix)
  end

  def get_digest_path(file_path, md_dir, alg)
    "#{get_metadata_path(file_path, md_dir)}.#{alg}"
  end

  def change_digest(file_path, md_dir, alg)
    File.open(get_digest_path(file_path, md_dir, alg), 'a') do |f|
      f.write("baddigest")
    end
  end

  def change_metadata(file_path, md_dir, append_content = "\n")
    md_path = get_metadata_path(file_path, md_dir)
    # Add content to the metadata to change it
    File.open(md_path, 'a') do |f|
      f.write(append_content)
    end
  end
end
