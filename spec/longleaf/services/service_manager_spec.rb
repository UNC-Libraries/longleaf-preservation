require 'spec_helper'
require 'longleaf/specs/file_helpers'
require 'longleaf/services/service_manager'
require 'longleaf/services/application_config_manager'
require 'longleaf/specs/config_builder'
require 'longleaf/errors'
require 'tmpdir'

describe Longleaf::ServiceManager do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:app_manager) { double(Longleaf::ApplicationConfigManager) }

  describe '.initialize' do
    it 'fails with missing parameters' do
      expect { Longleaf::ServiceManager.new }.to raise_error(ArgumentError)
    end

    it 'fails with nil parameters' do
      expect { build(:service_manager, definition_manager: nil, mapping_manager: nil, app_manager: nil) }.to raise_error(ArgumentError)
    end
  end

  describe '.service' do
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let(:path_dir) { Dir.mktmpdir('path') }
    let(:lib_dir) { make_test_dir(name: 'lib_dir') }

    let!(:work_script_file1) { create_work_class(lib_dir, 'PresService1', 'pres_service1.rb') }
    let!(:work_script_file2) { create_work_class(lib_dir, 'PresService2', 'pres_service2.rb') }

    before { $LOAD_PATH.unshift(lib_dir) }

    let(:config) {
      ConfigBuilder.new
        .with_service(name: 'serv1', work_script: work_script_file1)
        .with_service(name: 'serv2', work_script: work_script_file2)
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .map_services('loc1', ['serv1', 'serv2'])
        .get
    }
    let(:manager) { build(:service_manager, config: config, app_manager: app_manager) }

    after(:each) do
      $LOAD_PATH.delete(lib_dir)
      FileUtils.rm_rf([md_dir, path_dir, lib_dir])
    end

    it 'returns service matching provided name' do
      expect(manager.service('serv1').class.name).to eq 'PresService1'
      expect(manager.service('serv2').class.name).to eq 'PresService2'
    end

    it 'raises ArgumentError when no matching service name' do
      expect { manager.service('whoa_serv') }.to raise_error(ArgumentError)
    end

    it 'raises ArgumentError if no service name provided' do
      expect { manager.service(nil) }.to raise_error(ArgumentError)
    end
  end

  describe '.list_services' do
    context 'with empty sections' do
      let(:config) {
        ConfigBuilder.new
          .with_services
          .with_locations
          .with_mappings.get
      }
      let(:manager) { build(:service_manager, config: config, app_manager: app_manager) }

      it 'returns nothing' do
        expect(manager.list_services(location: 'loc1')).to be_empty
      end
    end

    context 'with mappings' do
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:path_dir) { Dir.mktmpdir('path') }
      let(:config) {
        ConfigBuilder.new
          .with_services
          .with_service(name: 'serv1')
          .with_service(name: 'serv2')
          .with_locations
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', ['serv1', 'serv2'])
          .get
      }
      let(:manager) { build(:service_manager, config: config, app_manager: app_manager) }

      after(:each) do
        FileUtils.rmdir([md_dir, path_dir])
      end

      it 'returns services for loc1' do
        result = manager.list_services(location: 'loc1')
        expect(result).to contain_exactly('serv1', 'serv2')
      end

      it 'returns empty list for unmapped location' do
        expect(manager.list_services(location: 'imaginary_place')).to be_empty
      end
    end
  end

  describe '.list_service_definitions' do
    context 'with mappings' do
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:path_dir) { Dir.mktmpdir('path') }
      let(:config) {
        ConfigBuilder.new
          .with_services
          .with_service(name: 'serv1')
          .with_service(name: 'serv2')
          .with_locations
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', ['serv1', 'serv2'])
          .get
      }
      let(:manager) { build(:service_manager, config: config, app_manager: app_manager) }

      after(:each) do
        FileUtils.rmdir([md_dir, path_dir])
      end

      it 'returns services for loc1' do
        result = manager.list_service_definitions(location: 'loc1')
        expect(result.length).to eq 2
        expect(result[0].name).to eq "serv1"
        expect(result[1].name).to eq "serv2"
      end

      it 'returns empty list for unmapped location' do
        expect(manager.list_service_definitions(location: 'imaginary_place')).to be_empty
      end
    end
  end

  describe '.applicable_for_event?' do
    context 'location with multiple services' do
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:path_dir) { Dir.mktmpdir('path') }
      let(:lib_dir) { make_test_dir(name: 'lib_dir') }

      let!(:work_script_file1) {
        create_work_class(lib_dir, 'ApplPresService', 'appl_pres_service.rb',
          is_applicable: true)
      }
      let!(:work_script_file2) {
        create_work_class(lib_dir, 'PresService', 'pres_service.rb',
          is_applicable: 'event != "preserve"')
      }

      before { $LOAD_PATH.unshift(lib_dir) }

      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1', work_script: work_script_file1)
          .with_service(name: 'serv2', work_script: work_script_file2)
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', ['serv1', 'serv2'])
          .get
      }
      let(:manager) { build(:service_manager, config: config, app_manager: app_manager) }

      after(:each) do
        $LOAD_PATH.delete(lib_dir)
        FileUtils.rm_rf([md_dir, path_dir, lib_dir])
      end

      it 'returns true for an applicable service' do
        expect(manager.applicable_for_event?('serv1', 'preserve')).to be true
      end

      it 'returns false for a non-applicable event' do
        expect(manager.applicable_for_event?('serv2', 'preserve')).to be false
      end

      it 'returns true for an applicable event' do
        expect(manager.applicable_for_event?('serv2', 'replicate')).to be true
      end
    end
  end

  describe '.perform_service' do
    context 'location with service that succeeds for preserve event' do
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:path_dir) { Dir.mktmpdir('path') }
      let(:lib_dir) { make_test_dir(name: 'lib_dir') }

      let!(:work_script_file) {
        create_work_class(lib_dir, 'PresService', 'pres_service.rb',
          perform: "raise Longleaf::PreservationServiceError.new if event == 'replicate'")
      }

      before { $LOAD_PATH.unshift(lib_dir) }

      let(:config) {
        ConfigBuilder.new
          .with_service(name: 'serv1', work_script: work_script_file)
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', ['serv1'])
          .get
      }
      let(:manager) { build(:service_manager, config: config, app_manager: app_manager) }

      after(:each) do
        $LOAD_PATH.delete(lib_dir)
        FileUtils.rm_rf([md_dir, path_dir, lib_dir])
      end

      context 'with metadata record' do
        let(:serv_rec) { build(:service_record, timestamp: Longleaf::ServiceDateHelper.formatted_timestamp) }
        let(:md_rec) { build(:metadata_record) }
        let(:file_rec) { build(:file_record, metadata_record: md_rec) }

        it 'succeeds for preserve event ' do
          expect { manager.perform_service('serv1', file_rec, 'preserve') }.to_not raise_error
        end

        it 'raises error for replicate event' do
          expect { manager.perform_service('serv1', file_rec, 'replicate') }.to raise_error(Longleaf::PreservationServiceError)
        end
      end
    end
  end
end
