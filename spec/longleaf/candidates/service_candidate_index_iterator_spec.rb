require 'spec_helper'
require 'longleaf/candidates/service_candidate_index_iterator'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/metadata_builder'
require 'longleaf/specs/system_config_builder'
require 'longleaf/specs/file_helpers'
require 'longleaf/errors'
require 'longleaf/specs/custom_matchers'
require 'fileutils'

describe Longleaf::ServiceCandidateIndexIterator do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  SysConfigBuilder ||= Longleaf::SystemConfigBuilder
  MetadataBuilder ||= Longleaf::MetadataBuilder
  SECONDS_IN_DAY ||= 60 * 60 * 24

  let(:md_dir1) { make_test_dir(name: 'metadata1') }
  let(:path_dir1) { make_test_dir(name: 'path1') }
  let(:db_file) { create_test_file(name: 'index.db', content: '') }

  after do
    FileUtils.rm_rf([md_dir1, path_dir1])
    FileUtils.rm(db_file)
  end

  let(:sys_config) {
    SysConfigBuilder.new
      .with_index('amalgalite', "amalgalite://#{db_file}")
      .get
  }
  let(:config) {
    ConfigBuilder.new
      .with_service(name: 'serv1', frequency: '1 days')
      .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
      .map_services(['loc1'], ['serv1'])
      .with_system(sys_config)
      .get
  }

  let(:app_config) { build(:application_config_manager, config: config) }

  let(:file_selector) {
    build(:file_selector,
      storage_locations: ['loc1'],
      app_config: app_config)
  }

  let(:iterator) {
    build(:service_candidate_index_iterator,
      file_selector: file_selector,
      app_config: app_config)
  }

  let(:storage_loc) { build(:storage_location, name: 'loc1', path: path_dir1, metadata_path: md_dir1) }

  before do
    app_config.index_manager.setup_index
  end

  describe '.next_candidate' do
    context 'no indexed files' do
      it { expect(iterator.next_candidate).to be_nil }
    end

    context 'no stale services' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", days_from_now(10)) }

      it { expect(iterator.next_candidate).to be_nil }
    end

    context 'multiple needing services' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", days_from_now(-3)) }
      let!(:file_rec2) { create_index_file_rec(storage_loc, "serv1", days_from_now(-4)) }

      it 'returns the records, stalest first' do
        expect(iterator.next_candidate).to eq file_rec2
        expect(iterator.next_candidate).to eq file_rec1
      end

      context 'with force flag' do
        let(:iterator) {
          build(:service_candidate_index_iterator,
            file_selector: file_selector,
            app_config: app_config,
            force: true)
        }

        it 'returns the records, stalest first' do
          expect(iterator.next_candidate).to eq file_rec2
          expect(iterator.next_candidate).to eq file_rec1
        end
      end

      context 'with service updates between retrieval' do
        it 'returns the records then returns nil' do
          expect(iterator.next_candidate).to eq file_rec2
          update_after_service(file_rec2, 'serv1')
          expect(iterator.next_candidate).to eq file_rec1
          update_after_service(file_rec1, 'serv1')
          expect(iterator.next_candidate).to be_nil
        end
      end
    end

    context 'multiple registered, some need services' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", days_from_now(-3)) }
      let!(:file_rec2) { create_index_file_rec(storage_loc, "serv1", days_from_now(1)) }
      let!(:file_rec3) { create_index_file_rec(storage_loc, "serv1", days_from_now(-2)) }

      it 'returns the records, stalest first, and then nil' do
        expect(iterator.next_candidate).to eq file_rec1
        expect(iterator.next_candidate).to eq file_rec3
      end

      context 'with force flag' do
        let(:iterator) {
          build(:service_candidate_index_iterator,
            file_selector: file_selector,
            app_config: app_config,
            force: true)
        }

        it 'returns the records, stalest first followed by forced record' do
          expect(iterator.next_candidate).to eq file_rec1
          expect(iterator.next_candidate).to eq file_rec3
          expect(iterator.next_candidate).to eq file_rec2
        end
      end
    end

    context 'indexed record that is not registered in the file system' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", days_from_now(-3)) }

      before do
        File.delete(file_rec1.metadata_path)
      end

      it 'returns nil' do
        expect(iterator.next_candidate).to be_nil
      end
    end

    # TODO test for cleanup event
  end

  describe '.each' do
    context 'with no files' do
      it 'processed no records' do
        result = Array.new
        iterator.each { |candidate| result << candidate.path }
        expect(result).to be_empty
      end
    end

    context 'with one file requiring service' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", days_from_now(-3)) }

      it 'iterates over file' do
        result = Array.new
        iterator.each do |candidate|
          result << candidate.path
          update_after_service(candidate, 'serv1')
        end
        expect(result).to contain_exactly(file_rec1.path)
      end
    end

    context 'with file that fails service' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", days_from_now(-3)) }

      it 'iterates over file once' do
        result = Array.new
        iterator.each do |candidate|
          result << candidate.path
          update_after_service(candidate, 'serv1', as_failed: true)
        end
        expect(result).to contain_exactly(file_rec1.path)
      end
    end

    context 'multiple files, some requiring services, one not' do
      let!(:file_rec1) { create_index_file_rec(storage_loc, "serv1", days_from_now(-3)) }
      let!(:file_rec2) { create_index_file_rec(storage_loc, "serv1", days_from_now(3)) }
      let!(:file_rec3) { create_index_file_rec(storage_loc, "serv1", days_from_now(-2)) }

      it 'iterates over file' do
        result = Array.new
        iterator.each do |candidate|
          result << candidate.path
          update_after_service(candidate, 'serv1')
        end
        expect(result).to eq [file_rec1.path, file_rec3.path]
      end
    end
  end

  def create_index_file_rec(storage_loc, with_service = nil, with_timestamp = nil)
    file_path = create_test_file(dir: storage_loc.path)
    file_rec = build(:file_record, file_path: file_path, storage_location: storage_loc)

    md_builder = MetadataBuilder.new(file_path: file_path)
    unless with_service.nil?
      md_builder.with_service(with_service, timestamp: with_timestamp)
    end
    md_builder.write_to_yaml_file(file_rec: file_rec)

    app_config.index_manager.index(file_rec)
    file_rec
  end

  def update_after_service(file_rec, service_name, as_failed: false)
    if as_failed
      # Set failure time in the future
      service = file_rec.metadata_record.service(service_name)
      service.failure_timestamp = Longleaf::ServiceDateHelper.formatted_timestamp
    else
      file_rec.metadata_record.update_service_as_performed(service_name)
    end

    app_config.index_manager.index(file_rec)
  end

  def days_from_now(offset)
    Time.now.utc + SECONDS_IN_DAY * offset
  end
end
