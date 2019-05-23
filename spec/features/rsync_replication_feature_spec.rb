require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/metadata_builder'
require 'longleaf/specs/config_builder'
require 'tempfile'
require 'yaml'
require 'fileutils'

describe 'rsync replication service', :type => :aruba do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  REPL_TO ||= Longleaf::ServiceFields::REPLICATE_TO

  let(:path_dir1) { Dir.mktmpdir('path1') }
  let(:md_dir1) { Dir.mktmpdir('metadata1') }
  let(:path_dir2) { Dir.mktmpdir('path2') }
  let(:md_dir2) { Dir.mktmpdir('metadata2') }

  let(:storage_loc1) { build(:storage_location, name: 'loc1', path: path_dir1, metadata_path: md_dir1) }
  let(:storage_loc2) { build(:storage_location, name: 'loc2', path: path_dir2, metadata_path: md_dir2) }

  after do
    FileUtils.rm_rf([md_dir1, path_dir1, md_dir2, path_dir2])
  end

  let!(:config_path) {
    ConfigBuilder.new
      .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
      .with_location(name: 'loc2', path: path_dir2, md_path: md_dir2)
      .with_service(name: 'repl_serv',
          work_script: 'rsync_replication_service',
          properties: { REPL_TO => ['loc2']} )
      .map_services('loc1', 'repl_serv')
      .write_to_yaml_file
  }

  context 'valid service config' do
    after do
      FileUtils.rm(config_path)
    end

    let!(:file_path) { create_and_register_file(storage_loc1) }

    context 'preserve by storage location' do
      before do
        run_command_and_stop("longleaf preserve -c #{config_path} -s loc1", fail_on_error: false)
      end

      it 'reports success and replicated file exists' do
        expect(last_command_started).to have_output(/SUCCESS preserve\[repl_serv\] #{file_path}/)
        expect(last_command_started).to have_exit_status(0)

        repl_path = File.join(path_dir2, File.basename(file_path))
        repl_md = storage_loc2.get_metadata_path_for(repl_path)

        expect(File).to exist(repl_path)
        expect(File).to exist(repl_md)
      end
    end

    # Test to verify LEF-46 works as expected
    context 'destination metadata directory does not exist' do
      before do
        FileUtils.rm_rf(md_dir2)

        run_command_and_stop("longleaf preserve -c #{config_path} -s loc1", fail_on_error: false)
      end

      it 'reports failure and does not replicate' do
        expect(last_command_started).to have_output(/Storage location 'loc2' specifies a 'metadata_path' directory which does not exist/)
        expect(last_command_started).to have_exit_status(1)

        repl_path = File.join(path_dir2, File.basename(file_path))
        repl_md = storage_loc2.get_metadata_path_for(repl_path)

        expect(File).to_not exist(repl_path)
        expect(File).to_not exist(repl_md)
      end
    end
  end

  def create_and_register_file(storage_loc)
    file_path = create_test_file(dir: storage_loc.path)
    file_rec = build(:file_record, file_path: file_path, storage_location: storage_loc)

    md_builder = Longleaf::MetadataBuilder.new(file_path: file_path)
    md_builder.write_to_yaml_file(file_rec: file_rec)

    file_path
  end
end
