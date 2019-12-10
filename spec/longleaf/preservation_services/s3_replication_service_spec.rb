require 'spec_helper'
require 'longleaf/errors'
require 'longleaf/preservation_services/s3_replication_service'
require 'longleaf/models/service_fields'
require 'longleaf/models/storage_types'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/config_builder'
require 'fileutils'

describe Longleaf::S3ReplicationService do
  include Longleaf::FileHelpers

  SF ||= Longleaf::ServiceFields
  ST ||= Longleaf::StorageTypes
  S3Service ||= Longleaf::S3ReplicationService
  ConfigBuilder ||= Longleaf::ConfigBuilder
  PRESERVE_EVENT ||= Longleaf::EventNames::PRESERVE

  let(:md_dest_dir) { Dir.mktmpdir('dest_metadata') }
  after(:each) do
    FileUtils.rm_rf([md_dest_dir])
  end

  describe '.initialize' do
    let(:config) {
      ConfigBuilder.new
        .with_services
        .with_location(name: 'dest_loc',
            path: 'https://example.s3.us-stubbed-1.amazonaws.com',
            s_type: ST::S3_STORAGE_TYPE,
            md_path: md_dest_dir)
        .with_mappings
        .get
    }
    let(:app_manager) { build(:application_config_manager, config: config) }

    context 'invalid replication collision policy' do
      let(:service_def) { make_service_def(['dest_loc'], collision: 'figureitoutwhenithappens') }

      it 'fails with invalid policy warning' do
        expect { S3Service.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /received invalid replica_collision_policy/)
      end
    end

    context 'valid replication collision policy' do
      let(:service_def) { make_service_def(['dest_loc'], collision: 'replace') }
      let(:service) { S3Service.new(service_def, app_manager) }

      it { expect(service.collision_policy).to eq 'replace' }
    end

    context 'non-s3 destination' do
      let(:config) {
        ConfigBuilder.new
          .with_services
          .with_location(name: 'dest_loc',
              path: 'https://example.s3.us-stubbed-1.amazonaws.com',
              s_type: ST::FILESYSTEM_STORAGE_TYPE,
              md_path: md_dest_dir)
          .with_mappings
          .get
        }
      let(:service_def) { make_service_def(['dest_loc'], collision: 'replace') }
      let(:service) { S3Service.new(service_def, app_manager) }

      it 'fails due to type' do
        expect { S3Service.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /which is not of type 's3'/)
      end
    end

    context 'unknown destination' do
      let(:service_def) { make_service_def(['what_loc']) }
      it 'fails with invalid policy warning' do
        expect { S3Service.new(service_def, app_manager) }.to raise_error(ArgumentError,
          /specifies unknown storage location/)
      end
    end
  end

  describe '.is_applicable?' do
    let(:dest1) { build(:s3_storage_location, metadata_path: md_dest_dir) }
    let(:locations) { {
      'dest_loc' => dest1
    } }
    let(:loc_manager) { instance_double('Longleaf::StorageLocationManager', :locations => locations) }
    let(:app_manager) { instance_double('Longleaf::ApplicationConfigManager', :location_manager => loc_manager) }

    let(:service_def) { make_service_def(['dest_loc']) }
    let(:service) { S3Service.new(service_def, app_manager) }

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
    let(:md_src_dir) { Dir.mktmpdir('metadata') }
    let(:path_src_dir) { Dir.mktmpdir('path') }
    after do
      FileUtils.rm_rf([md_src_dir, path_src_dir])
    end

    let(:app_manager) { instance_double('Longleaf::ApplicationConfigManager', :location_manager => loc_manager) }
    let(:dest1) { build(:s3_storage_location, metadata_path: md_dest_dir) }

    let(:loc_manager) { instance_double('Longleaf::StorageLocationManager', :locations => locations) }

    let(:service_def) { make_service_def(['dest_loc']) }
    let(:service) { S3Service.new(service_def, app_manager) }

    context 'file system to s3' do
      let(:source_loc) { build(:storage_location, path: path_src_dir, metadata_path: md_src_dir) }
      let(:md_rec) { build(:metadata_record) }
      let!(:original_file) { create_test_file(name: 'test_file.txt', dir: path_src_dir) }
      let(:file_rec) { make_file_record(original_file, md_rec, source_loc) }

      let(:locations) { {
        'dest_loc' => dest1,
        'source_loc' => source_loc
      } }

      context 'with file' do
        it 'replicates file to s3 destination' do
          service.perform(file_rec, PRESERVE_EVENT)

          s3_client = dest1.s3_client
          expect(s3_client.api_requests.size).to eq(2)
          expect(s3_client.api_requests.last[:params]).to include(
                  :bucket => "example",
                  :key => 'test_file.txt'
                )
        end
      end

      context 'with md5' do
        before do
          md_rec.checksums['MD5'] = '9a0364b9e99bb480dd25e1f0284c8555'
        end

        it 'replicates file to s3 destination' do
          service.perform(file_rec, PRESERVE_EVENT)

          s3_client = dest1.s3_client
          expect(s3_client.api_requests.size).to eq(2)
          expect(s3_client.api_requests.last[:params]).to include(
                  :bucket => "example",
                  :key => 'test_file.txt',
                  :content_md5 => 'mgNkuembtIDdJeHwKEyFVQ=='
                )
        end
      end

      context 'with invalid md5' do
        before do
          md_rec.checksums['MD5'] = '9a0364b9e99bohnodd25e1f0284c8555'
          dest1.s3_client.stub_responses(:put_object, 'BadDigest')
        end

        it { expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(Longleaf::ChecksumMismatchError) }
      end

      context 'with transfer error' do
        before do
          dest1.s3_client.stub_responses(:put_object, 'NoSuchUpload')
        end

        it { expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(Longleaf::PreservationServiceError) }
      end

      context 'with nested file' do
        let(:nested_src_dir) do
          nested_path = File.join(path_src_dir, 'nested')
          Dir.mkdir(nested_path)
          nested_path
        end
        let!(:original_file) { create_test_file(name: 'test_file.txt', dir: nested_src_dir) }

        it 'replicates file to s3 destination' do
          service.perform(file_rec, PRESERVE_EVENT)

          s3_client = dest1.s3_client
          expect(s3_client.api_requests.size).to eq(2)
          expect(s3_client.api_requests.last[:params]).to include(
                  :bucket => "example",
                  :key => 'nested/test_file.txt'
                )
        end
      end

      context 'destination not available' do
        before do
          dest1.s3_client.stub_responses(:head_bucket, 'NotFound')
        end

        it { expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(Longleaf::StorageLocationUnavailableError) }
      end

      context 'multiple destinations' do
        let(:md_dest_dir2) { Dir.mktmpdir('dest_metadata') }
        let(:dest2) { build(:s3_storage_location, path: 'https://anotherbucket.s3-amazonaws.com/', metadata_path: md_dest_dir2) }
        let(:locations) { {
          'dest_loc' => dest1,
          'dest_loc2' => dest2,
          'source_loc' => source_loc
        } }

        let(:service_def) { make_service_def(['dest_loc', 'dest_loc2']) }

        after do
          FileUtils.rm_rf([md_dest_dir2])
        end


        it 'replicates file to all s3 destinations' do
          service.perform(file_rec, PRESERVE_EVENT)

          s3_client = dest1.s3_client
          expect(s3_client.api_requests.size).to eq(2)
          expect(s3_client.api_requests.last[:params]).to include(
                  :bucket => "example",
                  :key => 'test_file.txt'
                )

          s3_client2 = dest2.s3_client
          expect(s3_client2.api_requests.size).to eq(2)
          expect(s3_client2.api_requests.last[:params]).to include(
                  :bucket => "anotherbucket",
                  :key => 'test_file.txt'
                )
        end
      end
    end

    context 's3 to s3' do
      let(:source_loc) { build(:s3_storage_location, path: 'https://anotherbucket.s3-amazonaws.com/', metadata_path: md_dest_dir) }
      let(:md_rec) { build(:metadata_record) }
      let!(:original_file) { 'https://anotherbucket.s3-amazonaws.com/original.txt' }
      let(:file_rec) { make_file_record(original_file, md_rec, source_loc) }

      let(:locations) { {
        'dest_loc' => dest1,
        'source_loc' => source_loc
      } }

      it { expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(Longleaf::PreservationServiceError) }
    end
  end

  private
  def make_service_def(destinations, collision: nil)
    properties = Hash.new
    properties[SF::REPLICATE_TO] = destinations
    properties[SF::COLLISION_PROPERTY] = collision unless collision.nil?
    build(:service_definition, properties: properties)
  end

  def make_file_record(file_path, md_rec, storage_loc)
    file_rec = build(:file_record, file_path: file_path, storage_location: storage_loc)
    file_rec.metadata_record = md_rec
    file_rec
  end
end
