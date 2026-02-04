require 'spec_helper'
require 'longleaf/errors'
require 'longleaf/helpers/ocfl_helper'
require 'longleaf/preservation_services/ocfl_rsync_replication_service'
require 'longleaf/models/service_fields'
require 'longleaf/models/md_fields'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/metadata_builder'
require 'fileutils'
require 'find'

describe Longleaf::OcflRsyncReplicationService do
  include Longleaf::FileHelpers

  SF ||= Longleaf::ServiceFields
  MDFields ||= Longleaf::MDFields
  OcflRsyncReplicationService ||= Longleaf::OcflRsyncReplicationService
  ConfigBuilder ||= Longleaf::ConfigBuilder
  MetadataBuilder ||= Longleaf::MetadataBuilder
  PRESERVE_EVENT ||= Longleaf::EventNames::PRESERVE

  let(:md_src_dir) { Dir.mktmpdir('metadata') }
  let(:path_src_dir) { Dir.mktmpdir('path') }
  let(:md_dest_dir) { Dir.mktmpdir('dest_metadata') }
  let(:path_dest_dir) { Dir.mktmpdir('dest_path') }
  let(:ocfl_object_path) { '141/964/af8/141964af842132b7a706ed010474c410514b472acc0d7d8f805c23e748578b8b' }

  let(:config) {
    ConfigBuilder.new
      .with_services
      .with_locations
      .with_location(name: 'source_loc', path: path_src_dir, md_path: md_src_dir)
      .with_location(name: 'dest_loc', path: path_dest_dir, md_path: md_dest_dir)
      .with_mappings
      .get
  }
  let(:app_manager) { build(:application_config_manager, config: config) }

  before do
    # Copy OCFL fixtures into path_src_dir
    fixtures_path = File.join(__dir__, '../../fixtures/ocfl-root')
    FileUtils.cp_r(fixtures_path, path_src_dir)
  end

  after(:each) do
    FileUtils.rm_rf([md_src_dir, path_src_dir, md_dest_dir, path_dest_dir])
  end

  describe '.initialize' do
    context 'invalid replication collision policy' do
      let(:service_def) { make_service_def(['dest_loc'], collision: 'figureitoutwhenithappens') }

      it {
        expect { OcflRsyncReplicationService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /received invalid replica_collision_policy/)
      }
    end

    context 'valid replication collision policy' do
      let(:service_def) { make_service_def(['dest_loc'], collision: 'replace') }
      let(:service) { OcflRsyncReplicationService.new(service_def, app_manager) }

      it { expect(service.collision_policy).to eq 'replace' }
    end

    context 'options contain disallowed short option' do
      let(:service_def) { make_service_def(['dest_loc'], options: '-h') }

      it {
        expect { OcflRsyncReplicationService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /specifies a disallowed rsync paramter/)
      }
    end

    context 'options contain disallowed long option' do
      let(:service_def) { make_service_def(['dest_loc'], options: '--exclude') }

      it {
        expect { OcflRsyncReplicationService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /specifies a disallowed rsync paramter/)
      }
    end

    context 'options contain disallowed short option in group' do
      let(:service_def) { make_service_def(['dest_loc'], options: '-Wh') }

      it {
        expect { OcflRsyncReplicationService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /specifies a disallowed rsync paramter/)
      }
    end

    context 'options contain allowed options' do
      let(:service_def) { make_service_def(['dest_loc'], options: '-W -vc --chmod "0440"') }
      let(:service) { OcflRsyncReplicationService.new(service_def, app_manager) }

      it "include all provided options" do
        expect(service.options).to eq '-W -vc --chmod "0440"'
      end
    end

    context 'default configuration' do
      let(:service_def) { make_service_def(['dest_loc']) }
      let(:service) { OcflRsyncReplicationService.new(service_def, app_manager) }

      it "has default configuration options" do
        expect(service.options).to eq '-a'
        expect(service.command).to eq 'rsync'
        expect(service.collision_policy).to eq 'replace'
      end
    end

    context 'destination as string' do
      let(:service_def) { make_service_def('dest_loc') }
      let(:service) { OcflRsyncReplicationService.new(service_def, app_manager) }

      it "creates service without errors" do
        expect(OcflRsyncReplicationService.new(service_def, app_manager)).to be_a(OcflRsyncReplicationService)
      end
    end

    context 'no destinations' do
      let(:service_def) { make_service_def([]) }

      it {
        expect { OcflRsyncReplicationService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /one or more replication destinations/)
      }
    end

    context 'invalid storage location destination' do
      let(:service_def) { make_service_def(['other_loc']) }

      it {
        expect { OcflRsyncReplicationService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /unknown storage location/)
      }
    end
  end

  describe '.is_applicable?' do
    let(:service_def) { make_service_def(['dest_loc']) }
    let(:service) { OcflRsyncReplicationService.new(service_def, app_manager) }

    it "returns true for replicate event" do
      expect(service.is_applicable?(Longleaf::EventNames::PRESERVE)).to be true
    end

    it "returns false for non-verify event" do
      expect(service.is_applicable?(Longleaf::EventNames::REGISTER)).to be false
    end

    it "returns false for invalid event" do
      expect(service.is_applicable?('nothanks')).to be false
    end
  end

  describe '.perform' do
    context "storage location destination" do
      let(:md_rec) { create_ocfl_metadata_record }
      let(:service_def) { make_service_def(['dest_loc']) }
      let(:service) { OcflRsyncReplicationService.new(service_def, app_manager) }

      it "replicates and registers OCFL object to destination storage location" do
        original_object_path = File.join(path_src_dir, 'ocfl-root', ocfl_object_path)
        file_rec = make_file_record(original_object_path, md_rec, "source_loc", app_manager)

        service.perform(file_rec, PRESERVE_EVENT)

        replica_path = File.join(path_dest_dir, 'ocfl-root', ocfl_object_path)

        # Verify all files exist in replica
        expect(Dir.exist?(replica_path)).to be true
        verify_all_files_replicated(original_object_path, replica_path)

        # Verify metadata was created
        replica_md_path = app_manager.location_manager.locations['dest_loc'].get_metadata_path_for(replica_path)
        expect(File.exist?(replica_md_path)).to be true
        replica_md = Longleaf::MetadataDeserializer.deserialize(file_path: replica_md_path)
        expect(replica_md.checksums).to include(md_rec.checksums)
      end

      it "raises error when destination location is not available" do
        original_object_path = File.join(path_src_dir, 'ocfl-root', ocfl_object_path)
        file_rec = make_file_record(original_object_path, md_rec, "source_loc", app_manager)

        # Remove the destination so that is is "unavailable"
        FileUtils.rmdir(path_dest_dir)

        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(Longleaf::StorageLocationUnavailableError)
      end

      context 'with additional rsync options' do
        let(:service_def) { make_service_def(['dest_loc'], options: '-Wa') }
        let(:service) { OcflRsyncReplicationService.new(service_def, app_manager) }

        it "replicates OCFL object to destination location" do
          original_object_path = File.join(path_src_dir, 'ocfl-root', ocfl_object_path)
          file_rec = make_file_record(original_object_path, md_rec, "source_loc", app_manager)

          service.perform(file_rec, PRESERVE_EVENT)

          replica_path = File.join(path_dest_dir, 'ocfl-root', ocfl_object_path)

          expect(Dir.exist?(replica_path)).to be true
          verify_all_files_replicated(original_object_path, replica_path)
        end
      end

      context 'with destination string' do
        let(:service_def) { make_service_def('dest_loc') }

        it "replicates OCFL object to destination location" do
          original_object_path = File.join(path_src_dir, 'ocfl-root', ocfl_object_path)
          file_rec = make_file_record(original_object_path, md_rec, "source_loc", app_manager)

          service.perform(file_rec, PRESERVE_EVENT)

          replica_path = File.join(path_dest_dir, 'ocfl-root', ocfl_object_path)
          expect(Dir.exist?(replica_path)).to be true
          verify_all_files_replicated(original_object_path, replica_path)
        end
      end

      context 'with bad command name' do
        let(:service_def) { make_service_def(['dest_loc'], command: 'totally_not_rsync') }
        let(:service) { OcflRsyncReplicationService.new(service_def, app_manager) }

        it "raises error when rsync command fails" do
          original_object_path = File.join(path_src_dir, 'ocfl-root', ocfl_object_path)
          file_rec = make_file_record(original_object_path, md_rec, "source_loc", app_manager)

          expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(Longleaf::PreservationServiceError)
        end
      end
    end

    context 'with path destination' do
      let(:md_rec) { create_ocfl_metadata_record }
      let(:dest_dir) { Dir.mktmpdir('dest') }
      let(:service_def) { make_service_def([dest_dir]) }
      let(:service) { OcflRsyncReplicationService.new(service_def, app_manager) }

      after do
        FileUtils.rm_rf(dest_dir)
      end

      it 'replicates OCFL object to destination' do
        original_object_path = File.join(path_src_dir, 'ocfl-root', ocfl_object_path)
        file_rec = make_file_record(original_object_path, md_rec, "source_loc", app_manager)

        service.perform(file_rec, PRESERVE_EVENT)

        replica_path = File.join(dest_dir, 'ocfl-root', ocfl_object_path)

        expect(Dir.exist?(replica_path)).to be true
        verify_all_files_replicated(original_object_path, replica_path)
      end

      it 'replicates nested OCFL object to nested destination' do
        # OCFL objects are already nested
        original_object_path = File.join(path_src_dir, 'ocfl-root', ocfl_object_path)
        file_rec = make_file_record(original_object_path, md_rec, "source_loc", app_manager)

        service.perform(file_rec, PRESERVE_EVENT)

        replica_path = File.join(dest_dir, 'ocfl-root', ocfl_object_path)

        expect(Dir.exist?(replica_path)).to be true
        verify_all_files_replicated(original_object_path, replica_path)
      end

      it 'raises error when destination is not available' do
        original_object_path = File.join(path_src_dir, 'ocfl-root', ocfl_object_path)
        file_rec = make_file_record(original_object_path, md_rec, "source_loc", app_manager)

        FileUtils.rmdir(dest_dir)

        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(Longleaf::StorageLocationUnavailableError)
      end
    end

    context 'with multiple destinations' do
      let(:md_rec) { create_ocfl_metadata_record }
      let(:dest_dir2) { Dir.mktmpdir('dest2') }
      let(:service_def) { make_service_def(["dest_loc", dest_dir2]) }
      let(:service) { OcflRsyncReplicationService.new(service_def, app_manager) }

      after do
        FileUtils.rm_rf(dest_dir2)
      end

      it 'replicates OCFL object to all destinations' do
        original_object_path = File.join(path_src_dir, 'ocfl-root', ocfl_object_path)
        file_rec = make_file_record(original_object_path, md_rec, "source_loc", app_manager)

        service.perform(file_rec, PRESERVE_EVENT)

        replica_path = File.join(path_dest_dir, 'ocfl-root', ocfl_object_path)

        expect(Dir.exist?(replica_path)).to be true
        verify_all_files_replicated(original_object_path, replica_path)

        replica_md_path = app_manager.location_manager.locations['dest_loc'].get_metadata_path_for(replica_path)
        expect(File.exist?(replica_md_path)).to be true

        replica_path2 = File.join(dest_dir2, 'ocfl-root', ocfl_object_path)

        expect(Dir.exist?(replica_path2)).to be true
        verify_all_files_replicated(original_object_path, replica_path2)
      end
    end
  end

  private

  def make_service_def(destinations, collision: nil, command: nil, options: nil)
    properties = Hash.new
    properties[SF::REPLICATE_TO] = destinations
    properties[SF::COLLISION_PROPERTY] = collision unless collision.nil?
    properties[OcflRsyncReplicationService::RSYNC_COMMAND_PROPERTY] = command unless command.nil?
    properties[OcflRsyncReplicationService::RSYNC_OPTIONS_PROPERTY] = options unless options.nil?
    build(:service_definition, properties: properties)
  end

  def make_file_record(file_path, md_rec, loc_name, app_manager)
    storage_loc = app_manager.location_manager.locations[loc_name]
    file_rec = build(:file_record, file_path: file_path, storage_location: storage_loc)
    file_rec.metadata_record = md_rec
    file_rec
  end

  def create_ocfl_metadata_record
    original_object_path = File.join(path_src_dir, 'ocfl-root', ocfl_object_path)
    total_size, file_count, last_modified = Longleaf::OcflHelper.summarized_file_info(original_object_path)

    build(:metadata_record,
      file_size: total_size,
      file_count: file_count,
      last_modified: last_modified,
      object_type: MDFields::OCFL_TYPE
    )
  end

  def verify_all_files_replicated(source_dir, dest_dir)
    # Get all files in source
    source_files = get_all_files_relative(source_dir)
    dest_files = get_all_files_relative(dest_dir)

    # Verify same number of files
    expect(dest_files.length).to eq(source_files.length),
      "Expected #{source_files.length} files in destination, found #{dest_files.length}"

    # Verify all source files exist in destination and have same content
    source_files.each do |rel_path|
      source_file = File.join(source_dir, rel_path)
      dest_file = File.join(dest_dir, rel_path)

      expect(File.exist?(dest_file)).to be(true), "Expected file #{rel_path} to exist in destination"
      expect(FileUtils.compare_file(source_file, dest_file)).to be(true),
        "Expected file #{rel_path} to have same content in source and destination"
    end
  end

  def get_all_files_relative(dir)
    files = []
    Find.find(dir) do |path|
      next if File.directory?(path)
      rel_path = Pathname.new(path).relative_path_from(Pathname.new(dir)).to_s
      files << rel_path
    end
    files
  end
end
