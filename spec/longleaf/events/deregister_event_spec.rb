require 'spec_helper'
require 'longleaf/models/file_record'
require 'longleaf/events/deregister_event'
require 'longleaf/events/register_event'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/services/metadata_serializer'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/metadata_builder'
require 'fileutils'
require 'tmpdir'
require 'tempfile'

describe Longleaf::DeregisterEvent do
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
        expect { Longleaf::DeregisterEvent.new(file_rec: nil, app_manager: app_config) }
          .to raise_error(ArgumentError, /Must provide a file_rec parameter/)
      }
      it {
        expect { Longleaf::DeregisterEvent.new(file_rec: 'file', app_manager: app_config) }
          .to raise_error(ArgumentError, /Parameter file_rec must be a FileRecord/)
      }
    end

    context 'without an application config manager' do
      let(:file_rec) { build(:file_record) }

      it {
        expect { Longleaf::DeregisterEvent.new(file_rec: file_rec, app_manager: nil) }
          .to raise_error(ArgumentError, /Must provide an ApplicationConfigManager/ )
      }
      it {
        expect { Longleaf::DeregisterEvent.new(file_rec: file_rec, app_manager: 'bad') }
          .to raise_error(ArgumentError, /Parameter app_manager must be an ApplicationConfigManager/)
      }
    end
  end

  describe '.perform' do
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let(:path_dir) { Dir.mktmpdir('path') }

    after do
      FileUtils.rm_rf([md_dir, path_dir])
    end

    let(:config) {
      ConfigBuilder.new
        .with_service(name: 'serv1')
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .map_services('loc1', 'serv1')
        .get
    }
    let(:app_config) { build(:application_config_manager, config: config) }

    let(:md_rec) {
      MDBuilder.new(file_path: file_path)
          .with_service('serv1')
          .get_metadata_record
    }
    let(:file_path) { create_test_file(dir: path_dir) }
    let(:storage_location) { app_config.location_manager.get_location_by_path(file_path) }
    let(:file_rec) {
      build(:file_record, file_path: file_path,
      storage_location: storage_location,
      metadata_record: md_rec)
    }

    context 'on a registered file' do
      let(:event) { Longleaf::DeregisterEvent.new(file_rec: file_rec, app_manager: app_config) }

      it 'successfully deregisters the file' do
        status = event.perform
        expect(status).to eq 0

        result_md = load_metadata_record(file_path)

        expect(result_md.deregistered?).to be true
        expect { Time.iso8601(result_md.deregistered) }.to_not raise_error
      end
    end

    context 'on a deregistered file' do
      let(:deregistered_timestamp) { Longleaf::ServiceDateHelper.formatted_timestamp(Time.now - 1) }
      let(:md_rec) {
        MDBuilder.new(file_path: file_path)
            .deregistered(deregistered_timestamp)
            .with_service('serv1')
            .with_properties({ 'custom' => 'value' })
            .get_metadata_record
      }

      context 'without force flag' do
        let(:event) { Longleaf::DeregisterEvent.new(file_rec: file_rec, app_manager: app_config) }

        it "fails and does not change metadata" do
          status = event.perform
          expect(status).to eq 1

          expect(md_rec.deregistered).to eq deregistered_timestamp
        end
      end

      context 'with force flag' do
        let(:event) {
          Longleaf::DeregisterEvent.new(file_rec: file_rec,
            app_manager: app_config,
            force: true)
        }

        it 'succeeds and updates deregisteration info for the file' do
          status = event.perform
          expect(status).to eq 0

          result_md = load_metadata_record(file_path)

          expect(result_md.deregistered?).to be true
          expect(result_md.deregistered).to_not eq deregistered_timestamp
          # custom property from original record retained
          expect(result_md.properties['custom']).to eq 'value'
        end
      end
    end

    def load_metadata_record(file_path)
      storage_loc = app_config.location_manager.get_location_by_path(file_path)
      metadata_path = storage_loc.get_metadata_path_for(file_path)
      Longleaf::MetadataDeserializer.deserialize(file_path: metadata_path)
    end
  end
end
