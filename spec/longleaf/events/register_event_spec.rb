require 'spec_helper'
require 'longleaf/models/file_record'
require 'longleaf/events/register_event'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/services/metadata_serializer'
require 'longleaf/errors'
require 'longleaf/specs/config_builder'
require 'fileutils'
require 'tmpdir'
require 'tempfile'

describe Longleaf::RegisterEvent do
  AppDeserializer ||= Longleaf::ApplicationConfigDeserializer
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
  describe '.initialize' do
    context 'without a file record' do
      let(:config) { ConfigBuilder.new
          .with_services
          .with_locations
          .with_mappings
          .get }
      let(:app_config) { build(:application_config_manager, config: config) }
      
      it { expect { Longleaf::RegisterEvent.new(file_rec: nil, app_manager: app_config) }
          .to raise_error(ArgumentError, /Must provide a file_rec parameter/) }
      it { expect { Longleaf::RegisterEvent.new(file_rec: 'file', app_manager: app_config) }
          .to raise_error(ArgumentError, /Parameter file_rec must be a FileRecord/) }
    end
    
    context 'without an application config manager' do
      let(:file_rec) { build(:file_record) }
    
      it { expect { Longleaf::RegisterEvent.new(file_rec: file_rec, app_manager: nil) }
          .to raise_error(ArgumentError, /Must provide an ApplicationConfigManager/ ) }
      it { expect { Longleaf::RegisterEvent.new(file_rec: file_rec, app_manager: 'bad') }
          .to raise_error(ArgumentError, /Parameter app_manager must be an ApplicationConfigManager/) }
    end
  end
  
  describe '.perform' do
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let(:path_dir) { Dir.mktmpdir('path') }
  
    after do
      FileUtils.remove_dir(md_dir)
      FileUtils.remove_dir(path_dir)
    end
    
    context 'file in location with services' do
      let(:config) { ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .map_services('loc1', 'serv1')
          .get }
      let(:app_config) { build(:application_config_manager, config: config) }
    
      let(:file_path) { make_test_file(path_dir, 'test_file') }
      let(:storage_location) { app_config.location_manager.get_location_by_path(file_path) }
      let(:file_rec) { build(:file_record, file_path: file_path, storage_location: storage_location) }
      
      let(:event) { Longleaf::RegisterEvent.new(file_rec: file_rec, app_manager: app_config) }
      
      it 'persists valid metadata file' do
        event.perform
        
        md_rec = load_metadata_record(file_path)

        expect { Time.iso8601(md_rec.registered) }.to_not raise_error

        expect(md_rec.file_size).to eq 7
        expect { Time.iso8601(md_rec.last_modified) }.to_not raise_error
        
        expect(md_rec.list_services).to include('serv1')
      end
      
      it 'raises RegistrationError for already registered file' do
        event.perform
        
        expect { event.perform }.to raise_error(Longleaf::RegistrationError,
            /already registered/)
      end
      
      it 'forces persistence of metadata file with retained property' do
        event.perform
        
        md_rec = file_rec.metadata_record
        md_rec.properties['keep_me'] = 'plz'
        update_metadata_record(file_rec.path, md_rec)
        
        force_event = Longleaf::RegisterEvent.new(file_rec: file_rec, app_manager: app_config, force: true)
        force_event.perform
        
        md_rec2 = load_metadata_record(file_path)
        expect(md_rec2.properties).to include('keep_me' => 'plz')
        expect { Time.iso8601(md_rec2.registered) }.to_not raise_error
      end
      
      it 'persists valid metadata file with force flag' do
        force_event = Longleaf::RegisterEvent.new(file_rec: file_rec, app_manager: app_config, force: true)
        force_event.perform
        
        md_rec = load_metadata_record(file_path)

        expect { Time.iso8601(md_rec.registered) }.to_not raise_error
      end
      
      it 'persists metadata with checksums' do
        event = Longleaf::RegisterEvent.new(file_rec: file_rec,
            app_manager: app_config,
            checksums: { 'md5' => 'digestvalue',
              'sha1' => 'shadigest' } )
        event.perform
        
        md_rec = load_metadata_record(file_path)

        expect { Time.iso8601(md_rec.registered) }.to_not raise_error
        expect(md_rec.list_services).to include('serv1')
        
        expect(md_rec.checksums).to include('md5' => 'digestvalue',
            'sha1' => 'shadigest')
      end
    end
    
    context 'file in location with no services' do
      let(:config) { ConfigBuilder.new
          .with_services
          .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
          .with_mappings
          .get }
      let(:app_config) { build(:application_config_manager, config: config) }
    
      let(:file_path) { make_test_file(path_dir, 'test_file') }
      let(:storage_location) { app_config.location_manager.get_location_by_path(file_path) }
      let(:file_rec) { build(:file_record, file_path: file_path, storage_location: storage_location) }
      
      let(:event) { Longleaf::RegisterEvent.new(file_rec: file_rec, app_manager: app_config) }
      
      it 'persists metadata file with no services' do
        event.perform
        
        md_rec = load_metadata_record(file_path)

        expect { Time.iso8601(md_rec.registered) }.to_not raise_error

        expect(md_rec.file_size).to eq 7
        expect { Time.iso8601(md_rec.last_modified) }.to_not raise_error
        
        expect(md_rec.list_services).to be_empty
      end
    end
    
    def make_test_file(dir, file_name = 'test_file', content = 'content')
      path = File.join(dir, file_name)
      File.open(path, 'w') { |f| f.write(content) }
      path
    end
    
    # @returns [Longleaf::MetadataRecord] the metadata record for file_path
    def load_metadata_record(file_path)
      storage_loc = app_config.location_manager.get_location_by_path(file_path)
      metadata_path = storage_loc.get_metadata_path_for(file_path)
      # puts "Record: #{File.read(metadata_path)}"
      Longleaf::MetadataDeserializer.deserialize(file_path: metadata_path)
    end
    
    def update_metadata_record(file_path, metadata_record)
      storage_loc = app_config.location_manager.get_location_by_path(file_path)
      metadata_path = storage_loc.get_metadata_path_for(file_path)
      Longleaf::MetadataSerializer.write(file_path: metadata_path, metadata: metadata_record)
    end
  end
end