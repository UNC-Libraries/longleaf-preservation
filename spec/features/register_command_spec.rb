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
              /Storage location 'loc1' specifies invalid location 'path' property: Path must not be empty/)
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
    let!(:file_path2) { create_test_file(dir: path_dir, name: 'another_file', content: 'more content') }

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

    context 'register directory of files' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{path_dir}/'", fail_on_error: false)
      end

      it 'registers both files' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect(metadata_created(file_path, md_dir)).to be true
        expect(last_command_started).to have_output(/SUCCESS register #{file_path2}/)
        expect(metadata_created(file_path2, md_dir)).to be true
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register file with separate physical path' do
      let!(:logical_path) { File.join(path_dir, "logical") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{logical_path}' -p '#{file_path}'",
             fail_on_error: false)
      end

      it 'registers file with physical path' do
        expect(last_command_started).to have_output(/SUCCESS register #{logical_path}/)
        expect(metadata_created(logical_path, md_dir)).to be true
        expect_physical_path(logical_path, file_path)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register file with same logical and physical path' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}' -p '#{file_path}'",
             fail_on_error: false)
      end

      it 'registers file without physical path' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect(metadata_created(file_path, md_dir)).to be true
        expect_physical_path(file_path, nil)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register two files with separate physical paths' do
      let!(:logical_path) { File.join(path_dir, "logical") }
      let!(:logical_path2) { File.join(path_dir, "logical2") }

      before do
        run_command_and_stop(%Q{longleaf register -c #{config_path} -f '#{logical_path},#{logical_path2}'
             -p '#{file_path},#{file_path2}'},
             fail_on_error: false)
      end

      it 'registers files with physical paths' do
        expect(last_command_started).to have_output(/SUCCESS register #{logical_path}/)
        expect(last_command_started).to have_output(/SUCCESS register #{logical_path2}/)
        expect(metadata_created(logical_path, md_dir)).to be true
        expect_physical_path(logical_path, file_path)
        expect(metadata_created(logical_path2, md_dir)).to be true
        expect_physical_path(logical_path2, file_path2)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register file with non-existent physical path' do
      let!(:logical_path) { File.join(path_dir, "logical") }
      let!(:physical_path) { File.join(path_dir, "physical") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{logical_path}' -p '#{physical_path}'",
             fail_on_error: false)
      end

      it 'rejects registration' do
        expect(last_command_started).to have_output(/FAILURE register: File #{physical_path} does not exist/)
        expect(metadata_created(logical_path, md_dir)).to be false
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'register file with physical path not in storage location' do
      let!(:logical_path) { File.join(path_dir, "logical") }
      let!(:physical_path) { create_test_file }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{logical_path}' -p '#{physical_path}'",
             fail_on_error: false)
      end

      it 'rejects registration' do
        expect(last_command_started).to have_output(
            /FAILURE register: Path #{physical_path} is not from a known storage location/)
        expect(metadata_created(logical_path, md_dir)).to be false
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'register existing logical path with physical path' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}' -p '#{file_path2}'",
             fail_on_error: false)
      end

      it 'register file with physical path' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect(metadata_created(file_path, md_dir)).to be true
        expect_physical_path(file_path, file_path2)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register two files with one physical path' do
      let!(:logical_path) { File.join(path_dir, "logical") }
      let!(:logical_path2) { File.join(path_dir, "logical2") }

      before do
        run_command_and_stop(%Q{longleaf register -c #{config_path} -f '#{logical_path},#{logical_path2}'
             -p '#{file_path}'}, fail_on_error: false)
      end

      it 'rejects mismatched parameters' do
        expect(last_command_started).to have_output(
            /FAILURE: Invalid physical paths parameter, number of paths did not match.*/)
        expect(metadata_created(logical_path, md_dir)).to be false
        expect(metadata_created(logical_path2, md_dir)).to be false
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'register one file with too many physical paths' do
      let!(:logical_path) { File.join(path_dir, "logical") }
      let!(:logical_path2) { File.join(path_dir, "logical2") }

      before do
        run_command_and_stop(%Q{longleaf register -c #{config_path} -f '#{logical_path}'
             -p '#{file_path},#{file_path2}'}, fail_on_error: false)
      end

      it 'rejects mismatched parameters' do
        expect(last_command_started).to have_output(
            /FAILURE: Invalid physical paths parameter, number of paths did not match.*/)
        expect(metadata_created(logical_path, md_dir)).to be false
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'reregister file that has physical path with new physical path' do
      let!(:logical_path) { File.join(path_dir, "logical") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{logical_path}' -p '#{file_path}'",
             fail_on_error: false)
        run_command_and_stop("longleaf register -c #{config_path} --force -f '#{logical_path}' -p '#{file_path2}'",
             fail_on_error: false)
      end

      it 'registers file with physical path' do
        expect(last_command_started).to have_output(/SUCCESS register #{logical_path}/)
        expect_physical_path(logical_path, file_path2)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'reregister file that has physical path with no physical path' do
      let!(:logical_path) { File.join(path_dir, "logical") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{logical_path}' -p '#{file_path}'",
             fail_on_error: false)
        FileUtils.touch(logical_path)
        run_command_and_stop("longleaf register -c #{config_path} --force -f '#{logical_path}'",
             fail_on_error: false)
      end

      it 'registers file with physical path' do
        expect(last_command_started).to have_output(/SUCCESS register #{logical_path}/)
        expect_physical_path(logical_path, nil)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'reregister file that does not have a physical path with a physical path' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        File.delete(file_path)
        run_command_and_stop(%Q{longleaf register -c #{config_path} --force -f '#{file_path}'
              -p #{file_path2}},
             fail_on_error: false)
      end

      it 'registers file with physical path' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect_physical_path(file_path, file_path2)
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
        expect_digests(file_path, md5: 'digest')
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'multiple valid checksums' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f '#{file_path}' --checksums 'md5:digest,sha1:anotherdigest'")
      end

      it 'registers the file' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect_digests(file_path, sha1: 'anotherdigest',
                                  md5: 'digest')
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register multiple from checksum manifest' do
      let!(:manifest_path) { create_manifest_file(
                   "e8241901910dac399e9fcd5fb5661e6923a0ce0a   #{file_path}\n" +
                   "013d5696728f086b8d2424b14beebc2695f926f7   #{file_path2}\n") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -m 'sha1:#{manifest_path}' --log_level DEBUG", fail_on_error: false)
      end

      it 'registers the files with digest' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect_digests(file_path, sha1: 'e8241901910dac399e9fcd5fb5661e6923a0ce0a')
        expect(last_command_started).to have_output(/SUCCESS register #{file_path2}/)
        md_rec2 = get_metadata_record(file_path2, md_dir)
        expect_digests(file_path2, sha1: '013d5696728f086b8d2424b14beebc2695f926f7')
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register multiple files with multiple checks from multiple manifests' do
      let!(:manifest_path) { create_manifest_file(
                   "e8241901910dac399e9fcd5fb5661e6923a0ce0a   #{file_path}\n" +
                   "013d5696728f086b8d2424b14beebc2695f926f7   #{file_path2}") }

      let!(:manifest_path2) { create_manifest_file(
                   "9f753c302ffa359ddb9a93fe979d6de1   #{file_path}\n" +
                   "ce6320a83ead310ae30d43ae0f338bcc   #{file_path2}") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -m sha1:#{manifest_path} md5:#{manifest_path2}", fail_on_error: false)
      end

      it 'registers the files with digests' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect_digests(file_path, sha1: 'e8241901910dac399e9fcd5fb5661e6923a0ce0a',
                                  md5: '9f753c302ffa359ddb9a93fe979d6de1')
        expect(last_command_started).to have_output(/SUCCESS register #{file_path2}/)
        expect_digests(file_path2, sha1: '013d5696728f086b8d2424b14beebc2695f926f7',
                                  md5: 'ce6320a83ead310ae30d43ae0f338bcc')

        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register multiple files with multiple checks from combined manifest' do
      let!(:manifest_path) { create_manifest_file(
                   "sha1:\n" +
                   "e8241901910dac399e9fcd5fb5661e6923a0ce0a   #{file_path}\n" +
                   "013d5696728f086b8d2424b14beebc2695f926f7   #{file_path2}\n" +
                   "md5:\n" +
                   "9f753c302ffa359ddb9a93fe979d6de1   #{file_path}"
                   ) }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -m #{manifest_path}", fail_on_error: false)
      end

      it 'registers the files with digests' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect_digests(file_path, sha1: 'e8241901910dac399e9fcd5fb5661e6923a0ce0a',
                                  md5: '9f753c302ffa359ddb9a93fe979d6de1')
        expect(last_command_started).to have_output(/SUCCESS register #{file_path2}/)
        expect_digests(file_path2, sha1: '013d5696728f086b8d2424b14beebc2695f926f7')
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register from manifest without specifying algorithm' do
      let!(:manifest_path) { create_manifest_file(
                   "e8241901910dac399e9fcd5fb5661e6923a0ce0a   #{file_path}") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -m #{manifest_path}", fail_on_error: false)
      end

      it 'fails to register' do
        expect(last_command_started).to have_output(/FAILURE: Manifest with unknown checksums encountered, an algorithm must be specified/)
        expect(metadata_created(file_path, md_dir)).to be false
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'register files from piped checksum manifest' do
      let!(:manifest_path) { create_manifest_file(
                   "e8241901910dac399e9fcd5fb5661e6923a0ce0a   #{file_path}\n" +
                   "013d5696728f086b8d2424b14beebc2695f926f7   #{file_path2}\n") }

      before do
        run_command("longleaf register -c #{config_path} -m sha1:@-", fail_on_error: false)
        pipe_in_file(manifest_path)
        close_input
      end

      it 'registers the files with digest' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect_digests(file_path, sha1: 'e8241901910dac399e9fcd5fb5661e6923a0ce0a')
        expect(last_command_started).to have_output(/SUCCESS register #{file_path2}/)
        expect_digests(file_path2, sha1: '013d5696728f086b8d2424b14beebc2695f926f7')
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register files from piped combined manifest' do
      let!(:manifest_path) { create_manifest_file(
                   "sha1:\n" +
                   "e8241901910dac399e9fcd5fb5661e6923a0ce0a   #{file_path}\n" +
                   "013d5696728f086b8d2424b14beebc2695f926f7   #{file_path2}\n" +
                   "md5:\n" +
                   "9f753c302ffa359ddb9a93fe979d6de1   #{file_path}"
                   ) }

      before do
        run_command("longleaf register -c #{config_path} -m @-", fail_on_error: false)
        pipe_in_file(manifest_path)
        close_input
      end

      it 'registers the files with digest' do
        expect(last_command_started).to have_output(/SUCCESS register #{file_path}/)
        expect_digests(file_path, sha1: 'e8241901910dac399e9fcd5fb5661e6923a0ce0a',
                                  md5: '9f753c302ffa359ddb9a93fe979d6de1')
        expect(last_command_started).to have_output(/SUCCESS register #{file_path2}/)
        expect_digests(file_path2, sha1: '013d5696728f086b8d2424b14beebc2695f926f7')
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register files from multiple stdin manifests' do
      let!(:manifest_path) { create_manifest_file(
                   "e8241901910dac399e9fcd5fb5661e6923a0ce0a   #{file_path}\n" +
                   "013d5696728f086b8d2424b14beebc2695f926f7   #{file_path2}\n") }

      before do
        run_command("longleaf register -c #{config_path} -m sha1:@- md5:@-", fail_on_error: false)
        pipe_in_file(manifest_path)
        close_input
      end

      it 'fails to registers files' do
        expect(last_command_started).to have_output(/FAILURE: Cannot specify more than one manifest from STDIN/)
        expect(metadata_created(file_path, md_dir)).to be false
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'register files from invalid manifest' do
      let!(:manifest_path) { create_manifest_file(
                   "what is\n" +
                   "even happening\n" +
                   "here") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -m sha1:#{manifest_path}", fail_on_error: false)
      end

      it 'fails to registers files' do
        expect(last_command_started).to have_output(/FAILURE: Invalid manifest entry: here/)
        expect(metadata_created(file_path, md_dir)).to be false
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'register files manifest param listing algorithm with combined manifest' do
      let!(:manifest_path) { create_manifest_file(
                   "sha1:\n" +
                   "e8241901910dac399e9fcd5fb5661e6923a0ce0a   #{file_path}"
                   ) }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -m sha1:#{manifest_path}", fail_on_error: false)
      end

      it 'returns error' do
        expect(last_command_started).to have_output(/FAILURE: Invalid manifest entry: sha1:/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'register multiple from checksum manifest with physical paths' do
      let!(:logical_path) { File.join(path_dir, "logical") }
      let!(:logical_path2) { File.join(path_dir, "logical2") }
      let!(:manifest_path) { create_manifest_file(
                   "e8241901910dac399e9fcd5fb5661e6923a0ce0a  #{logical_path} #{file_path}\n" +
                   "013d5696728f086b8d2424b14beebc2695f926f7  #{logical_path2} #{file_path2}\n") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -m 'sha1:#{manifest_path}'", fail_on_error: false)
      end

      it 'registers the files with digest and physical paths' do
        expect(last_command_started).to have_output(/SUCCESS register #{logical_path}/)
        expect_digests(logical_path, sha1: 'e8241901910dac399e9fcd5fb5661e6923a0ce0a')
        expect_physical_path(logical_path, file_path)
        expect(last_command_started).to have_output(/SUCCESS register #{logical_path2}/)
        expect_digests(logical_path2, sha1: '013d5696728f086b8d2424b14beebc2695f926f7')
        expect_physical_path(logical_path2, file_path2)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register multiple from checksum manifest, one with physical path' do
      let!(:logical_path) { File.join(path_dir, "logical") }
      let!(:manifest_path) { create_manifest_file(
                   "e8241901910dac399e9fcd5fb5661e6923a0ce0a  #{logical_path} #{file_path}\n" +
                   "013d5696728f086b8d2424b14beebc2695f926f7  #{file_path2}\n") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -m 'sha1:#{manifest_path}'", fail_on_error: false)
      end

      it 'registers the files with digests and physical path' do
        expect(last_command_started).to have_output(/SUCCESS register #{logical_path}/)
        expect_digests(logical_path, sha1: 'e8241901910dac399e9fcd5fb5661e6923a0ce0a')
        expect_physical_path(logical_path, file_path)
        expect(last_command_started).to have_output(/SUCCESS register #{file_path2}/)
        expect_digests(file_path2, sha1: '013d5696728f086b8d2424b14beebc2695f926f7')
        expect_physical_path(file_path2, nil)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'register from checksum manifest with spaces in logical and physical path' do
      let!(:logical_path) { File.join(path_dir, "logical space") }
      let!(:physical_path) { create_test_file(dir: path_dir, name: 'spacey file', content: 'more content') }
      let!(:manifest_path) { create_manifest_file(
                   "013d5696728f086b8d2424b14beebc2695f926f7  '#{logical_path}' '#{physical_path}'\n") }

      before do
        run_command_and_stop("longleaf register -c #{config_path} -m 'sha1:#{manifest_path}'", fail_on_error: false)
      end

      it 'registers the files with digest and physical path' do
        expect(last_command_started).to have_output(/SUCCESS register #{logical_path}/)
        expect_digests(logical_path, sha1: '013d5696728f086b8d2424b14beebc2695f926f7')
        expect_physical_path(logical_path, physical_path)
        expect(last_command_started).to have_exit_status(0)
      end
    end
  end

  def get_metadata_record_path(file_path, md_dir)
    File.join(md_dir, File.basename(file_path) + Longleaf::MetadataSerializer::metadata_suffix)
  end

  def get_metadata_record(file_path, md_dir)
    Longleaf::MetadataDeserializer.deserialize(file_path: get_metadata_record_path(file_path, md_dir))
  end

  def metadata_created(file_path, md_dir)
    File.exist?(get_metadata_record_path(file_path, md_dir))
  end

  def metadata_contains_digest(file_path, md_dir, alg, digest)
    metadata_path = get_metadata_record_path(file_path, md_dir)
    md_rec = Longleaf::MetadataDeserializer.deserialize(file_path: metadata_path)
    md_rec.checksums[alg]
  end

  def expect_digests(file_path, md5: nil, sha1: nil)
    md_rec = get_metadata_record(file_path, md_dir)
    if md5.nil?
      expect(md_rec.checksums).not_to include('md5')
    else
      expect(md_rec.checksums['md5']).to eq md5
    end
    if sha1.nil?
      expect(md_rec.checksums).not_to include('sha1')
    else
      expect(md_rec.checksums['sha1']).to eq sha1
    end
  end

  def expect_physical_path(logical_path, physical_path)
    md_rec = get_metadata_record(logical_path, md_dir)
    if physical_path.nil?
      expect(md_rec.physical_path).to be_nil
    else
      expect(md_rec.physical_path).to eq physical_path
    end
  end

  def create_manifest_file(body)
    @m_index = @m_index.nil? ? 0 : @m_index + 1
    create_test_file(dir: path_dir, name: "manifest#{@m_index}.txt", content: body)
  end
end
