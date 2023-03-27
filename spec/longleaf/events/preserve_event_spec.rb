require 'spec_helper'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/metadata_builder'
require 'longleaf/events/preserve_event'
require 'longleaf/services/service_manager'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/helpers/service_date_helper'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'
require 'fileutils'
require 'tmpdir'
require 'tempfile'
require 'digest'

describe Longleaf::PreserveEvent do
  include Longleaf::FileHelpers

  ConfigBuilder ||= Longleaf::ConfigBuilder
  MDBuilder ||= Longleaf::MetadataBuilder

  describe '.initialize' do
    context 'without a file record' do
      let(:config) {
        ConfigBuilder.new
          .with_services
          .with_locations
          .with_mappings
          .get
      }
      let(:app_config) { build(:application_config_manager, config: config) }

      it {
        expect { Longleaf::PreserveEvent.new(file_rec: nil, app_manager: app_config) }
          .to raise_error(ArgumentError, /Must provide a file_rec parameter/)
      }
    end

    context 'without an application config manager' do
      let(:file_rec) { build(:file_record) }

      it {
        expect { Longleaf::PreserveEvent.new(file_rec: file_rec, app_manager: nil) }
          .to raise_error(ArgumentError, /Must provide an ApplicationConfigManager/ )
      }
    end
  end

  describe '.perform' do
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let(:path_dir) { Dir.mktmpdir('path') }
    let(:file_path) { create_test_file(dir: path_dir, name: 'test_file') }

    let(:index_manager) { instance_double("Longleaf::IndexManager", using_index?: false) }
    let(:md_manager) { Longleaf::MetadataPersistenceManager.new(index_manager) }
    let(:storage_loc) { build(:storage_location, path: path_dir, metadata_path: md_dir) }
    let(:storage_loc_manager) {
      instance_double("Longleaf::StorageLocationManager",
        :get_location_by_path => storage_loc)
    }
    let(:service_manager) { instance_double("Longleaf::ServiceManager") }
    let(:app_config) {
      instance_double("Longleaf::ApplicationConfigManager",
        :location_manager => storage_loc_manager,
        :service_manager => service_manager,
        :md_manager => md_manager)
    }

    let(:file_rec) { build(:file_record, file_path: file_path, storage_location: storage_loc) }
    let!(:md_path) { register(file_rec) }

    let(:event) { Longleaf::PreserveEvent.new(file_rec: file_rec, app_manager: app_config) }

    after do
      FileUtils.remove_dir(md_dir)
      FileUtils.remove_dir(path_dir)
    end

    context 'in location with no services' do
      before do
        allow(service_manager).to receive(:list_services) { [] }
      end

      it 'makes no updates to file metadata record' do
        perform_and_verify_no_change(event, md_path)
      end
    end

    context 'in location with one service' do
      before do
        allow(service_manager).to receive(:list_services) { ['serv1'] }
      end

      context 'service needs to run for the first time' do
        before do
          allow(service_manager).to receive(:service_needed?) { true }
          allow(service_manager).to receive(:perform_service)
        end

        it 'registers the service as having run' do
          perform_and_verify_run(event, file_rec, ['serv1'], service_manager)
        end
      end

      context 'service raises error' do
        before do
          allow(service_manager).to receive(:service_needed?) { true }
          allow(service_manager).to receive(:perform_service).and_raise(Longleaf::PreservationServiceError.new)
        end

        it 'registers the service as having failed' do
          perform_and_verify_no_change(event, md_path, expected_status: 1)
        end
      end

      context 'service raises StorageLocationUnavailableError' do
        before do
          allow(service_manager).to receive(:service_needed?) { true }
          allow(service_manager).to receive(:perform_service).and_raise(Longleaf::StorageLocationUnavailableError.new)
        end

        it 'throws the error' do
          expect { event.perform }.to raise_error(Longleaf::StorageLocationUnavailableError)
        end
      end

      context 'service has run previously' do
        let(:service_rec) { build(:service_record, timestamp: Longleaf::ServiceDateHelper.formatted_timestamp(Time.now.utc - 1)) }
        let(:md_rec) {
          MDBuilder.new(file_path: file_path)
              .with_service('serv1', timestamp: Longleaf::ServiceDateHelper.formatted_timestamp(Time.now.utc - 1))
              .get_metadata_record
        }
        let(:file_rec) {
          build(:file_record, file_path: file_path,
            storage_location: storage_loc, metadata_record: md_rec)
        }
        let!(:md_path) { register(file_rec) }

        context 'does not need to run again' do
          before do
            allow(service_manager).to receive(:service_needed?) { false }
          end

          it 'makes no updates to file metadata record' do
            perform_and_verify_no_change(event, md_path)
          end

          context 'with index enabled' do
            let(:index_manager) { double(using_index?: true) }
            before do
              allow(index_manager).to receive(:index)
            end

            it 'makes no updates to file metadata record, but updates the index in case its stale' do
              perform_and_verify_no_change(event, md_path)
              expect(index_manager).to have_received(:index).with(file_rec)
            end
          end
        end

        context 'needs to run again' do
          before do
            allow(service_manager).to receive(:perform_service)
            allow(service_manager).to receive(:service_needed?) { true }
          end

          it 'service run and timestamp updated' do
            perform_and_verify_run(event, file_rec, ['serv1'], service_manager)
          end
        end

        context 'with force flag' do
          let(:event) { Longleaf::PreserveEvent.new(file_rec: file_rec, app_manager: app_config, force: true) }

          before do
            allow(service_manager).to receive(:perform_service)
            allow(service_manager).to receive(:service_needed?) { false }
          end

          it 'service run and timestamp updated' do
            perform_and_verify_run(event, file_rec, ['serv1'], service_manager)
          end
        end
      end
    end

    context 'in location with multiple services' do
      let(:service_names) { ['serv1', 'serv2', 'serv3'] }

      before do
        allow(service_manager).to receive(:service_needed?) { true }
        allow(service_manager).to receive(:list_services) { service_names }
      end

      context 'all need to be run' do
        it 'service run and all timestamps updated' do
          perform_and_verify_run(event, file_rec, service_names, service_manager)
        end
      end

      context 'one service does not need to run' do
        before do
          allow(service_manager).to receive(:service_needed?) { true }
          allow(service_manager).to receive(:service_needed?).with('serv2', any_args) { false }
          allow(service_manager).to receive(:list_services) { service_names }
        end

        it 'ran services one and two' do
          perform_and_verify_run(event, file_rec, ['serv1', 'serv3'], service_manager)
        end
      end

      context 'one service raises an error' do
        before do
          allow(service_manager).to receive(:service_needed?) { true }
          allow(service_manager).to receive(:perform_service).with('serv2', any_args).and_raise( Longleaf::PreservationServiceError.new)
          allow(service_manager).to receive(:list_services) { service_names }
        end

        it 'ran services one and two' do
          expect(service_manager).to receive(:perform_service).with('serv1', file_rec, 'preserve')
          expect(service_manager).to receive(:perform_service).with('serv2', file_rec, 'preserve')
          expect(service_manager).to receive(:perform_service).with('serv3', file_rec, 'preserve')

          status = event.perform
          expect(status).to eq 2

          # Expect only the first service to have completed
          updated_md = load_metadata_record(file_rec)
          expect(updated_md.service('serv1').timestamp).to_not be_nil
          expect(updated_md.service('serv2')).to be_nil
          expect(updated_md.service('serv3').timestamp).to_not be_nil
        end
      end
    end
  end

  def perform_and_verify_run(event, file_rec, service_names, service_manager, expected_status: 0)
    original_timestamps = Hash.new
    md_rec = load_metadata_record(file_rec)
    service_names.each do |service_name|
      original_timestamps[service_name] = md_rec.service(service_name)&.timestamp
      expect(service_manager).to receive(:perform_service).with(service_name, file_rec, 'preserve')
    end

    status = event.perform
    expect(status).to eq expected_status

    updated_md = load_metadata_record(file_rec)
    service_names.each do |service_name|
      # verify that the timestamp updated
      updated_timestamp = updated_md.service(service_name).timestamp
      expect(updated_timestamp).to_not be_nil
      expect(updated_timestamp).to_not eq original_timestamps[service_name]
    end
  end

  def perform_and_verify_no_change(event, md_path, expected_status: 0)
    md_digest = Digest::SHA1.file(md_path)

    status = event.perform
    expect(status).to eq expected_status

    expect(md_digest).to eq Digest::SHA1.file(md_path)
  end

  def register(file_rec)
    md_rec = file_rec.metadata_record || MDBuilder.new(file_path: file_rec.path).get_metadata_record
    metadata_path = file_rec.storage_location.get_metadata_path_for(file_path)
    Longleaf::MetadataSerializer.write(file_path: metadata_path, metadata: md_rec)
    file_rec.metadata_record = md_rec
    metadata_path
  end

  def load_metadata_record(file_rec)
    storage_loc = file_rec.storage_location
    metadata_path = storage_loc.get_metadata_path_for(file_path)
    Longleaf::MetadataDeserializer.deserialize(file_path: metadata_path)
  end
end
