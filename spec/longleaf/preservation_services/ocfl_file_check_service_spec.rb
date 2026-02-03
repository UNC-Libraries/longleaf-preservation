require 'spec_helper'
require 'longleaf/errors'
require 'longleaf/helpers/ocfl_helper'
require 'longleaf/preservation_services/ocfl_file_check_service'
require 'longleaf/models/service_fields'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/metadata_builder'
require 'longleaf/specs/config_builder'
require 'longleaf/models/md_fields'
require 'fileutils'
require 'tmpdir'
require 'find'

describe Longleaf::OcflFileCheckService do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  MetadataBuilder ||= Longleaf::MetadataBuilder
  OcflFileCheckService ||= Longleaf::OcflFileCheckService
  PRESERVE_EVENT ||= Longleaf::EventNames::PRESERVE
  PreservationServiceError ||= Longleaf::PreservationServiceError
  MDFields ||= Longleaf::MDFields

  let(:md_dir) { Dir.mktmpdir('metadata') }
  let(:path_dir) { Dir.mktmpdir('path') }
  let(:ocfl_object_path) { '141/964/af8/141964af842132b7a706ed010474c410514b472acc0d7d8f805c23e748578b8b' }

  let(:config) {
    ConfigBuilder.new
      .with_services
      .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
      .with_mappings
      .get
  }
  let(:app_manager) { build(:application_config_manager, config: config) }

  before do
    # Copy OCFL fixtures into path_dir
    fixtures_path = File.join(__dir__, '../../fixtures/ocfl-root')
    FileUtils.cp_r(fixtures_path, path_dir)

    # Set known timestamps for testing (Git doesn't preserve mtimes)
    known_time = Time.parse('2026-01-26T18:48:00Z')
    recent_time = Time.parse('2026-01-26T18:50:00Z')
    Find.find(File.join(path_dir, 'ocfl-root')) do |path|
      next if File.directory?(path)
      timestamp = File.basename(path) == 'fcr-root.json' ? recent_time : known_time
      File.utime(timestamp, timestamp, path)
    end
  end

  after do
    FileUtils.remove_dir(md_dir)
    FileUtils.remove_dir(path_dir)
  end

  describe '.initialize' do
    context 'with service definition' do
      let(:service_def) { build(:service_definition) }

      it { expect(OcflFileCheckService.new(service_def, app_manager)).to be_a(OcflFileCheckService) }
    end
  end

  describe '.is_applicable?' do
    context 'with service definition' do
      let(:service_def) { build(:service_definition) }
      let(:service) { OcflFileCheckService.new(service_def, app_manager) }

      it "returns true for preserve event" do
        expect(service.is_applicable?(PRESERVE_EVENT)).to be true
      end

      it "returns false for non-preserve event" do
        expect(service.is_applicable?(Longleaf::EventNames::REGISTER)).to be false
      end

      it "returns false for invalid event" do
        expect(service.is_applicable?('nope')).to be false
      end
    end
  end

  describe '.perform' do
    let(:service_def) { build(:service_definition) }
    let(:service) { OcflFileCheckService.new(service_def, app_manager) }

    let!(:file_rec) { create_registered_ocfl_object }

    context 'with OCFL object matching registered details' do
      it { expect { service.perform(file_rec, PRESERVE_EVENT) }.to_not raise_error }
    end

    context 'with OCFL object that has been moved' do
      before do
        FileUtils.mv(file_rec.path, File.join(path_dir, 'moved_to_here'))
      end

      it 'raises PreservationServiceError' do
        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(PreservationServiceError,
            /OCFL directory does not exist: #{file_rec.path}/)
      end
    end

    context 'with OCFL object where a file has been modified' do
      before do
        updated_time = Time.parse('2026-01-29T10:11:00Z')
        file_to_modify = File.join(path_dir, 'ocfl-root/141/964/af8/141964af842132b7a706ed010474c410514b472acc0d7d8f805c23e748578b8b/v1/content/.fcrepo/fcr-root.json')
        File.utime(updated_time, updated_time, file_to_modify)
      end

      it 'raises PreservationServiceError' do
        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(PreservationServiceError,
            /Last modified timestamp for OCFL object #{file_rec.physical_path} does not match the expected value/)
      end
    end

    context 'with OCFL object where total file size does not match' do
      before do
        allow(file_rec.metadata_record).to receive(:file_size).and_return(999)
      end

      it 'raises PreservationServiceError' do
        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(PreservationServiceError,
            /File size for OCFL object #{file_rec.physical_path} does not match the expected value: registered = 999 bytes, actual = 2819 bytes/)
      end
    end

    context 'with OCFL object where file count does not match' do
      before do
        allow(file_rec.metadata_record).to receive(:file_count).and_return(3)
      end

      it 'raises PreservationServiceError' do
        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(PreservationServiceError,
            /File count for OCFL object #{file_rec.physical_path} does not match the expected value: registered = 3 files, actual = 7 files/)
      end
    end

    context 'with OCFL object where a file has been added' do
      before do
        # Add a new file to the OCFL object
        new_file_path = File.join(file_rec.path, 'v1', 'content', 'extra_file.txt')
        File.write(new_file_path, 'unexpected content')
      end

      it 'raises PreservationServiceError' do
        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(PreservationServiceError,
            /File count for OCFL object #{file_rec.physical_path} does not match the expected value: registered = 7 files, actual = 8 files/)
      end
    end

    context 'with OCFL object where a file has been deleted' do
      before do
        # Delete one of the files in the OCFL object
        file_to_delete = File.join(file_rec.path, 'v1/content/.fcrepo/fcr-root.json')
        FileUtils.rm(file_to_delete)
      end

      it 'raises PreservationServiceError due to file count mismatch' do
        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(PreservationServiceError,
            /File count for OCFL object #{file_rec.physical_path} does not match the expected value: registered = 7 files, actual = 6 files/)
      end
    end
  end

  def create_registered_ocfl_object
    file_path = File.join(path_dir, 'ocfl-root', ocfl_object_path)
    storage_loc = app_manager.location_manager.get_location_by_path(file_path)
    file_rec = build(:file_record, storage_location: storage_loc, file_path: file_path)

    # Calculate the actual OCFL object stats
    total_size, file_count, last_modified = Longleaf::OcflHelper.summarized_file_info(file_path)

    MetadataBuilder.new(file_path: file_path)
        .with_file_count(file_count)
        .with_last_modified(last_modified)
        .with_file_size(total_size)
        .with_object_type(MDFields::OCFL_TYPE)
        .register_to(file_rec)

    file_rec
  end
end
