require 'spec_helper'
require 'longleaf/services/metadata_serializer'
require 'longleaf/candidates/service_candidate_filesystem_iterator'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'longleaf/errors'
require 'longleaf/specs/custom_matchers'
require 'fileutils'

describe Longleaf::ServiceCandidateFilesystemIterator do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:md_dir1) { make_test_dir(name: 'metadata1') }
  let(:path_dir1) { make_test_dir(name: 'path1') }
  let(:lib_dir) { make_test_dir(name: 'lib_dir') }

  before { $LOAD_PATH.unshift(lib_dir) }

  after do
    FileUtils.rm_rf([md_dir1, path_dir1, lib_dir])
  end

  let!(:work_script_file) { create_work_class(lib_dir, 'PresService', 'pres_service.rb') }

  let(:app_config) { build(:application_config_manager, config: config) }

  let(:file_selector) {
    build(:file_selector,
      storage_locations: ['loc1'],
      app_config: app_config)
  }

  let(:iterator) {
    build(:service_candidate_filesystem_iterator,
      file_selector: file_selector,
      app_config: app_config)
  }

  describe '.next_candidate' do
    context 'configured with one service' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1', frequency: '10 days', work_script: work_script_file)
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
          .map_services(['loc1'], ['serv1'])
          .get
      }

      it 'returns nil given no files' do
        expect(iterator.next_candidate).to be_nil
      end

      context 'file unregistered' do
        let!(:file_path1) { create_test_file(dir: path_dir1) }

        it { expect(iterator.next_candidate).to be_nil }
      end

      context 'file with no services needed' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record) { build(:service_record, :timestamp_now) }
        before { create_metadata(file_path1, { 'serv1' => service_record}, app_config) }

        it 'skips unregistered file' do
          expect(iterator.next_candidate).to be_nil
        end
      end

      context 'file with run_needed true' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record) { build(:service_record, :timestamp_now, run_needed: true) }
        before { create_metadata(file_path1, { 'serv1' => service_record}, app_config) }

        it 'returns file with run_needed' do
          expect(iterator.next_candidate).to be_file_record_for(file_path1)
          expect(iterator.next_candidate).to be_nil
        end
      end

      context 'file with no services needed, with force flag' do
        let(:iterator) {
          build(:service_candidate_filesystem_iterator,
            file_selector: file_selector,
            app_config: app_config,
            force: true)
        }

        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record) { build(:service_record, :timestamp_now) }
        before { create_metadata(file_path1, { 'serv1' => service_record}, app_config) }

        it 'returns file' do
          expect(iterator.next_candidate).to be_file_record_for(file_path1)
          expect(iterator.next_candidate).to be_nil
        end
      end

      context 'file with service with no timestamp' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        before { create_metadata(file_path1, { 'serv1' => build(:service_record)}, app_config) }

        it 'returns file with no service timestamp' do
          expect(iterator.next_candidate).to be_file_record_for(file_path1)
          expect(iterator.next_candidate).to be_nil
        end
      end

      context 'file with service with stale timestamp' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record) { build(:service_record, timestamp: "2000-01-01T00:00:00Z") }
        before { create_metadata(file_path1, { 'serv1' => service_record}, app_config) }

        it 'returns file with stale timestamp' do
          expect(iterator.next_candidate).to be_file_record_for(file_path1)
          expect(iterator.next_candidate).to be_nil
        end
      end

      context 'file with no service record' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        before { create_metadata(file_path1, nil, app_config) }

        it 'returns file no service record' do
          expect(iterator.next_candidate).to be_file_record_for(file_path1)
          expect(iterator.next_candidate).to be_nil
        end
      end

      context 'multiple files with service needed' do
        let(:file_path1) { create_test_file(dir: path_dir1, name: "file1") }
        let(:file_path2) { create_test_file(dir: path_dir1, name: "file2") }
        let(:service_record) { build(:service_record, run_needed: true) }
        before do
          create_metadata(file_path1, { 'serv1' => service_record}, app_config)
          create_metadata(file_path2, { 'serv1' => service_record}, app_config)
        end

        it 'returns files with service needed' do
          expect(iterator.next_candidate).to be_file_record_for(file_path1)
          expect(iterator.next_candidate).to be_file_record_for(file_path2)
          expect(iterator.next_candidate).to be_nil
        end
      end

      context 'selecting file which does not exist' do
        let(:file_selector) {
          build(:file_selector,
            file_paths: [File.join(path_dir1, 'not_exist')],
            app_config: app_config)
        }

        it { expect { iterator.next_candidate }.to raise_error(Longleaf::InvalidStoragePathError, /does not exist/) }
      end

      context 'selecting multiple files where one does not exist' do
        let(:file_path1) { create_test_file(dir: path_dir1, name: "file1") }
        let(:file_selector) {
          build(:file_selector,
            file_paths: [File.join(path_dir1, 'not_exist'), file_path1],
            app_config: app_config)
        }
        before { create_metadata(file_path1, nil, app_config) }

        it 'returns file which exists' do
          expect { iterator.next_candidate }.to raise_error(Longleaf::InvalidStoragePathError, /not_exist does not exist/)
          expect(iterator.next_candidate).to be_file_record_for(file_path1)
          expect(iterator.next_candidate).to be_nil
        end
      end

      context 'deregistered file with run_needed true' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record) { build(:service_record, :timestamp_now, run_needed: true) }
        before do
          create_metadata(file_path1, { 'serv1' => service_record}, app_config,
              deregistered: "2000-01-01T00:00:00Z")
        end

        it 'returns no candidates' do
          expect(iterator.next_candidate).to be_nil
        end
      end

      context 'deregistered file with run_needed true in cleanup event' do
        let(:iterator) {
          build(:service_candidate_filesystem_iterator,
            file_selector: file_selector,
            app_config: app_config,
            event: Longleaf::EventNames::CLEANUP)
        }

        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record) { build(:service_record, :timestamp_now, run_needed: true) }
        before do
          create_metadata(file_path1, { 'serv1' => service_record}, app_config,
              deregistered: "2000-01-01T00:00:00Z")
        end

        it 'returns file with run_needed' do
          expect(iterator.next_candidate).to be_file_record_for(file_path1)
          expect(iterator.next_candidate).to be_nil
        end
      end
    end

    context 'configured location with multiple services' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1', work_script: work_script_file)
          .with_service(name: 'serv2', work_script: work_script_file)
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
          .map_services(['loc1'], ['serv1', 'serv2'])
          .get
      }

      context 'file with one service that does not need run, one that does' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record1) { build(:service_record, :timestamp_now) }
        let(:service_record2) { build(:service_record, run_needed: true) }
        before do
          create_metadata(file_path1, {
              'serv1' => service_record1,
              'serv2' => service_record2
            }, app_config)
        end

        it 'returns file' do
          expect(iterator.next_candidate).to be_file_record_for(file_path1)
          expect(iterator.next_candidate).to be_nil
        end
      end

      context 'file with multiple services needing to run' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record) { build(:service_record) }
        before do
          create_metadata(file_path1, {
              'serv1' => service_record,
              'serv2' => service_record
            }, app_config)
        end

        it 'returns file' do
          expect(iterator.next_candidate).to be_file_record_for(file_path1)
          expect(iterator.next_candidate).to be_nil
        end
      end

      context 'file with no services needing to run' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record) { build(:service_record, :timestamp_now) }
        before do
          create_metadata(file_path1, {
              'serv1' => service_record,
              'serv2' => service_record
            }, app_config)
        end

        it 'returns file' do
          expect(iterator.next_candidate).to be_nil
        end
      end
    end

    context 'configured location with no services' do
      let(:config) {
        ConfigBuilder.new
          .with_services
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
          .with_mappings
          .get
      }

      context 'file with one service that does not need run, one that does' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        before { create_metadata(file_path1, nil, app_config) }

        it 'returns file' do
          expect(iterator.next_candidate).to be_nil
        end
      end
    end

    context 'configured service with no frequency attribute' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1', work_script: work_script_file)
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
          .map_services(['loc1'], ['serv1'])
          .get
      }

      context 'file with service with old timestamp' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record) { build(:service_record, timestamp: "2000-01-01T00:00:00Z") }
        before { create_metadata(file_path1, { 'serv1' => service_record}, app_config) }

        it 'returns file with stale timestamp' do
          expect(iterator.next_candidate).to be_nil
        end
      end
    end
  end

  describe '.each' do
    context 'configured with a service' do
      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1', frequency: '10 days', work_script: work_script_file)
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
          .map_services(['loc1'], ['serv1'])
          .get
      }

      context 'with no files' do
        it do
          result = Array.new
          iterator.each { |candidate| result << candidate.path }
          expect(result).to be_empty
        end
      end

      context 'with one file not requiring any services' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record) { build(:service_record, :timestamp_now) }
        before { create_metadata(file_path1, { 'serv1' => service_record }, app_config) }

        it 'iterates over no files' do
          result = Array.new
          iterator.each { |candidate| result << candidate.path }
          expect(result).to be_empty
        end
      end

      context 'with one file requiring service' do
        let(:file_path1) { create_test_file(dir: path_dir1) }
        let(:service_record) { build(:service_record, run_needed: true) }
        before { create_metadata(file_path1, { 'serv1' => service_record}, app_config) }

        it 'iterates over file' do
          result = Array.new
          iterator.each { |candidate| result << candidate.path }
          expect(result).to contain_exactly(file_path1)
        end
      end

      context 'with multiple files requiring services' do
        let(:file_path1) { create_test_file(dir: path_dir1, name: 'file1') }
        let(:file_path2) { create_test_file(dir: path_dir1, name: 'file2') }
        let(:service_record) { build(:service_record, run_needed: true) }
        before do
          create_metadata(file_path1, { 'serv1' => service_record}, app_config)
          create_metadata(file_path2, { 'serv1' => service_record}, app_config)
        end

        it 'iterates over both files' do
          result = Array.new
          iterator.each { |candidate| result << candidate.path }
          expect(result).to contain_exactly(file_path1, file_path2)
        end
      end

      context 'with multiple files, some requiring services' do
        let(:file_path1) { create_test_file(dir: path_dir1, name: 'file1') }
        let(:file_path2) { create_test_file(dir: path_dir1, name: 'file2') }
        let(:file_path3) { create_test_file(dir: path_dir1, name: 'file3') }
        let(:service_record1) { build(:service_record, run_needed: true) }
        let(:service_record2) { build(:service_record, :timestamp_now) }
        before do
          create_metadata(file_path1, { 'serv1' => service_record1}, app_config)
          create_metadata(file_path2, { 'serv1' => service_record2}, app_config)
          create_metadata(file_path3, { 'serv1' => service_record1}, app_config)
        end

        it 'iterates over two files' do
          result = Array.new
          iterator.each { |candidate| result << candidate.path }
          expect(result).to contain_exactly(file_path1, file_path3)
        end
      end
    end
  end

  def write_metadata(md_rec, file_path, app_config)
    loc = app_config.location_manager.get_location_by_path(file_path)
    md_path = loc.get_metadata_path_for(file_path)

    Longleaf::MetadataSerializer.write(metadata: md_rec, file_path: md_path)
  end

  def create_metadata(file_path, services, app_config, deregistered: nil)
    md = build(:metadata_record, deregistered: deregistered)
    unless services.nil?
      services.each do |name, record|
        md.add_service(name, record)
      end
    end
    write_metadata(md, file_path, app_config)
  end
end
