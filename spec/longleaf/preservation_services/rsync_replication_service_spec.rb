require 'spec_helper'
require 'longleaf/errors'
require 'longleaf/preservation_services/rsync_replication_service'
require 'longleaf/models/service_fields'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/config_builder'
require 'fileutils'

describe Longleaf::RsyncReplicationService do
  include Longleaf::FileHelpers
  
  RsyncService ||= Longleaf::RsyncReplicationService
  ConfigBuilder ||= Longleaf::ConfigBuilder
  PRESERVE_EVENT ||= Longleaf::EventNames::PRESERVE
  
  let(:md_src_dir) { Dir.mktmpdir('metadata') }
  let(:path_src_dir) { Dir.mktmpdir('path') }
  let(:md_dest_dir) { Dir.mktmpdir('dest_metadata') }
  let(:path_dest_dir) { Dir.mktmpdir('dest_path') }
  let(:config) { ConfigBuilder.new
      .with_services
      .with_locations
      .with_location(name: 'source_loc', path: path_src_dir, md_path: md_src_dir)
      .with_location(name: 'dest_loc', path: path_dest_dir, md_path: md_dest_dir)
      .with_mappings
      .get }
  let(:app_manager) { build(:application_config_manager, config: config) }
  
  after(:each) do
    FileUtils.rm_rf([md_src_dir, path_src_dir, md_dest_dir, path_dest_dir])
  end
  
  describe '.initialize' do
    context 'invalid replication collision policy' do
      let(:service_def) { make_service_def(['dest_loc'], collision: 'figureitoutwhenithappens') }
      
      it { expect { RsyncService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /received invalid replica_collision_policy/) }
    end
    
    context 'valid replication collision policy' do
      let(:service_def) { make_service_def(['dest_loc'], collision: 'replace') }
      let(:service) { RsyncService.new(service_def, app_manager) }
      
      it { expect(service.collision_policy).to eq 'replace' }
    end
    
    context 'options contain disallowed short option' do
      let(:service_def) { make_service_def(['dest_loc'], options: '-h') }
      
      it { expect { RsyncService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /specifies a disallowed rsync paramter/) }
    end
    
    context 'options contain disallowed long option' do
      let(:service_def) { make_service_def(['dest_loc'], options: '--exclude') }
      
      it { expect { RsyncService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /specifies a disallowed rsync paramter/) }
    end
    
    context 'options contain disallowed short option in group' do
      let(:service_def) { make_service_def(['dest_loc'], options: '-Wh') }
      
      it { expect { RsyncService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /specifies a disallowed rsync paramter/) }
    end
    
    context 'options contain allowed options' do
      let(:service_def) { make_service_def(['dest_loc'], options: '-W -vc --chmod "0440"') }
      let(:service) { RsyncService.new(service_def, app_manager) }
      
      it "include all provided options plus -R" do
        expect(service.options).to eq '-W -vc --chmod "0440" -R'
      end
    end
    
    context 'default configuration' do
      let(:service_def) { make_service_def(['dest_loc']) }
      let(:service) { RsyncService.new(service_def, app_manager) }
      
      it "has default configuration options" do
        expect(service.options).to eq '-a -R'
        expect(service.command).to eq 'rsync'
        expect(service.collision_policy).to eq 'replace'
      end
    end
    
    context 'no destinations' do
      let(:service_def) { make_service_def([]) }
      
      it { expect { RsyncService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /one or more replication destinations/) }
    end
    
    context 'invalid storage location destination' do
      let(:service_def) { make_service_def(['other_loc']) }
      
      it { expect { RsyncService.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /unknown storage location/) }
    end
  end
  
  describe '.is_applicable?' do
    let(:service_def) { make_service_def(['dest_loc']) }
    let(:service) { RsyncService.new(service_def, app_manager) }

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
      let(:md_rec) { build(:metadata_record, checksums: {
          'md5' => 'digestvalue',
          'sha1' => 'shadigest' } ) }
      
      let(:service_def) { make_service_def(['dest_loc']) }
      let(:service) { RsyncService.new(service_def, app_manager) }
      
      it "replicates and registers file to destination storage location" do
        original_file = create_test_file(dir: path_src_dir)
        file_rec = make_file_record(original_file, md_rec, "source_loc", app_manager)
        
        service.perform(file_rec, PRESERVE_EVENT)
        
        replica_path = File.join(path_dest_dir, File.basename(original_file))
        
        expect(File.exist?(replica_path)).to be true
        expect(FileUtils.compare_file(original_file, replica_path)).to be true
        
        replica_md_path = app_manager.location_manager.locations['dest_loc'].get_metadata_path_for(replica_path)
        expect(File.exist?(replica_md_path)).to be true
        replica_md = Longleaf::MetadataDeserializer.deserialize(file_path: replica_md_path)
        expect(replica_md.checksums).to include('md5' => 'digestvalue', 'sha1' => 'shadigest')
      end
      
      it "replicates and registers file to nested path in destination storage location" do
        # Create test file within nested path
        original_path = File.join(path_src_dir, "nested/path/to/")
        FileUtils.mkdir_p(original_path)
        original_file = create_test_file(dir: original_path)
        file_rec = make_file_record(original_file, md_rec, "source_loc", app_manager)
        
        service.perform(file_rec, PRESERVE_EVENT)
        
        replica_path = File.join(path_dest_dir, "nested/path/to/", File.basename(original_file))
        
        expect(File.exist?(replica_path)).to be true
        expect(FileUtils.compare_file(original_file, replica_path)).to be true
        
        replica_md_path = app_manager.location_manager.locations['dest_loc'].get_metadata_path_for(replica_path)
        expect(File.exist?(replica_md_path)).to be true
        expect(File.zero?(replica_md_path)).to be false
      end
      
      it "raises error when destination location is not available" do
        original_file = create_test_file(dir: path_src_dir)
        file_rec = make_file_record(original_file, md_rec, "source_loc", app_manager)
        
        # Remove the destination so that is is "unavailable"
        FileUtils.rmdir(path_dest_dir)
        
        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(Longleaf::StorageLocationUnavailableError)
      end
      
      context 'with additional rsync options' do
        let(:service_def) { make_service_def(['dest_loc'], options: '-Wa') }
        let(:service) { RsyncService.new(service_def, app_manager) }
        
        it "replicates file to destination location" do
          original_file = create_test_file(dir: path_src_dir)
          file_rec = make_file_record(original_file, md_rec, "source_loc", app_manager)
          
          service.perform(file_rec, PRESERVE_EVENT)
        
          replica_path = File.join(path_dest_dir, File.basename(original_file))
        
          expect(File.exist?(replica_path)).to be true
          expect(FileUtils.compare_file(original_file, replica_path)).to be true
        end
      end
      
      context 'with bad command name' do
        let(:service_def) { make_service_def(['dest_loc'], command: 'totally_not_rsync') }
        let(:service) { RsyncService.new(service_def, app_manager) }
        
        it "raises error when destination location is not available" do
          original_file = create_test_file(dir: path_src_dir)
          file_rec = make_file_record(original_file, md_rec, "source_loc", app_manager)
        
          expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(Longleaf::PreservationServiceError)
        end
      end
    end
    
    context 'with path destination' do
      let(:md_rec) { build(:metadata_record) }
      let(:dest_dir) { Dir.mktmpdir('dest') }
      let(:service_def) { make_service_def([dest_dir]) }
      let(:service) { RsyncService.new(service_def, app_manager) }
      
      it 'replicates file to destination' do
        original_file = create_test_file(dir: path_src_dir)
        file_rec = make_file_record(original_file, md_rec, "source_loc", app_manager)
        
        service.perform(file_rec, PRESERVE_EVENT)
        
        replica_path = File.join(dest_dir, File.basename(original_file))
        
        expect(File.exist?(replica_path)).to be true
        expect(FileUtils.compare_file(original_file, replica_path)).to be true
      end
      
      it 'replicates nested file to nested destination' do
        original_path = File.join(path_src_dir, "nested/path/to/")
        FileUtils.mkdir_p(original_path)
        original_file = create_test_file(dir: original_path)
        file_rec = make_file_record(original_file, md_rec, "source_loc", app_manager)
        
        service.perform(file_rec, PRESERVE_EVENT)
        
        replica_path = File.join(dest_dir, "nested/path/to/", File.basename(original_file))
         
        expect(File.exist?(replica_path)).to be true
        expect(FileUtils.compare_file(original_file, replica_path)).to be true
      end
      
      it 'raises error when destination is not available' do
        original_file = create_test_file(dir: path_src_dir)
        file_rec = make_file_record(original_file, md_rec, "source_loc", app_manager)
        
        FileUtils.rmdir(dest_dir)
        
        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(Longleaf::StorageLocationUnavailableError)
      end
    end
    
    context 'with multiple destinations' do
      let(:md_rec) { build(:metadata_record) }
      let(:dest_dir2) { Dir.mktmpdir('dest2') }
      let(:service_def) { make_service_def(["dest_loc", dest_dir2]) }
      let(:service) { RsyncService.new(service_def, app_manager) }
      
      it 'replicates file to all destinations' do
        original_file = create_test_file(dir: path_src_dir)
        file_rec = make_file_record(original_file, md_rec, "source_loc", app_manager)
        
        service.perform(file_rec, PRESERVE_EVENT)
        
        replica_path = File.join(path_dest_dir, File.basename(original_file))
        
        expect(File.exist?(replica_path)).to be true
        expect(FileUtils.compare_file(original_file, replica_path)).to be true
        
        replica_md_path = app_manager.location_manager.locations['dest_loc'].get_metadata_path_for(replica_path)
        expect(File.exist?(replica_md_path)).to be true
        
        replica_path2 = File.join(dest_dir2, File.basename(original_file))
        
        expect(File.exist?(replica_path2)).to be true
        expect(FileUtils.compare_file(original_file, replica_path2)).to be true
      end
    end
  end
  
  private
  def make_service_def(destinations, collision: nil, command: nil, options: nil)
    properties = Hash.new
    properties[Longleaf::ServiceFields::REPLICATE_TO] = destinations
    properties[RsyncService::COLLISION_PROPERTY] = collision unless collision.nil?
    properties[RsyncService::RSYNC_COMMAND_PROPERTY] = command unless command.nil?
    properties[RsyncService::RSYNC_OPTIONS_PROPERTY] = options unless options.nil?
    build(:service_definition, properties: properties)
  end
  
  def make_file_record(file_path, md_rec, loc_name, app_manager)
    storage_loc = app_manager.location_manager.locations[loc_name]
    file_rec = build(:file_record, file_path: file_path, storage_location: storage_loc)
    file_rec.metadata_record = md_rec
    file_rec
  end
end