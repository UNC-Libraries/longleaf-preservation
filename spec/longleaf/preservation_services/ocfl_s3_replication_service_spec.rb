require 'spec_helper'
require 'longleaf/errors'
require 'longleaf/preservation_services/ocfl_s3_replication_service'
require 'longleaf/models/md_fields'
require 'longleaf/models/service_fields'
require 'longleaf/models/storage_types'
require 'longleaf/specs/file_helpers'
require 'digest/md5'
require 'fileutils'
require 'find'
require 'tmpdir'

describe Longleaf::OcflS3ReplicationService do
  include Longleaf::FileHelpers

  SF   ||= Longleaf::ServiceFields
  ST   ||= Longleaf::StorageTypes
  OcflS3Service ||= Longleaf::OcflS3ReplicationService
  PRESERVE_EVENT ||= Longleaf::EventNames::PRESERVE
  PreservationServiceError ||= Longleaf::PreservationServiceError

  OCFL_OBJECT_REL_PATH = '141/964/af8/141964af842132b7a706ed010474c410514b472acc0d7d8f805c23e748578b8b'
  OCFL_FIXTURE_PATH = File.expand_path('../../fixtures/ocfl-root', __dir__) + File::SEPARATOR

  # ── shared infrastructure ──────────────────────────────────────────────────

  let(:md_dest_dir)  { Dir.mktmpdir('dest_metadata') }
  let(:md_src_dir)   { Dir.mktmpdir('src_metadata') }
  let(:path_src_dir) { Dir.mktmpdir('src_path') }

  after(:each) do
    FileUtils.rm_rf([md_dest_dir, md_src_dir, path_src_dir])
  end

  # Copies the OCFL fixtures into path_src_dir so tests can mutate freely.
  def setup_ocfl_fixture
    FileUtils.cp_r(OCFL_FIXTURE_PATH, path_src_dir)
  end

  def ocfl_object_path
    File.join(path_src_dir, 'ocfl-root', OCFL_OBJECT_REL_PATH)
  end

  # S3 key prefix for files in the OCFL object: includes the bucket subpath + the
  # path of the object relative to the storage location root (which includes 'ocfl-root/').
  def s3_object_prefix
    "path/ocfl-root/#{OCFL_OBJECT_REL_PATH}"
  end

  # Build a stub OCFL storage location that reports type 'ocfl' and can relativize paths.
  def build_ocfl_location(path: path_src_dir, md_path: md_src_dir, mutable_head: false)
    loc = instance_double('Longleaf::OcflStorageLocation',
      name: 'ocfl_src',
      type: ST::OCFL_STORAGE_TYPE,
      path: path
    )
    allow(loc).to receive(:relativize) { |fp| fp.sub(/\A#{Regexp.escape(path.chomp('/'))}\// , '') }
    allow(loc).to receive(:mutable_head?).and_return(mutable_head)
    allow(loc).to receive(:default_object_type).and_return(Longleaf::MDFields::OCFL_TYPE)
    loc
  end

  def make_file_record(object_path, storage_loc)
    build(:file_record,
      file_path: object_path,
      storage_location: storage_loc,
      physical_path: object_path)
  end

  def make_service_def(destinations, collision: nil)
    properties = {}
    properties[SF::REPLICATE_TO] = destinations
    properties[SF::COLLISION_PROPERTY] = collision unless collision.nil?
    build(:service_definition, properties: properties)
  end

  let(:loc_manager) { instance_double('Longleaf::StorageLocationManager',
        locations: { 'dest_loc' => dest }) }
  let(:app_manager) { instance_double('Longleaf::ApplicationConfigManager',
        location_manager: loc_manager) }

  # ── initialize ────────────────────────────────────────────────────────────

  describe '.initialize' do
    let(:dest) { build(:s3_storage_location, metadata_path: md_dest_dir) }


    context 'with valid configuration' do
      let(:service_def) { make_service_def(['dest_loc']) }

      it 'constructs without error' do
        expect { OcflS3Service.new(service_def, app_manager) }.not_to raise_error
      end

      it 'uses the default collision policy' do
        service = OcflS3Service.new(service_def, app_manager)
        expect(service.collision_policy).to eq(SF::DEFAULT_COLLISION_POLICY)
      end
    end

    context 'with an explicit valid collision policy' do
      let(:service_def) { make_service_def(['dest_loc'], collision: 'replace') }

      it 'accepts the policy' do
        service = OcflS3Service.new(service_def, app_manager)
        expect(service.collision_policy).to eq('replace')
      end
    end

    context 'with an invalid collision policy' do
      let(:service_def) { make_service_def(['dest_loc'], collision: 'do_nothing') }

      it 'raises ArgumentError' do
        expect { OcflS3Service.new(service_def, app_manager) }
          .to raise_error(ArgumentError, /invalid replica_collision_policy/)
      end
    end

    context 'with no destinations' do
      let(:service_def) { make_service_def([]) }

      it 'raises ArgumentError' do
        expect { OcflS3Service.new(service_def, app_manager) }
          .to raise_error(ArgumentError, /one or more replication destinations/)
      end
    end

    context 'with an unknown destination' do
      let(:service_def) { make_service_def(['nowhere_loc']) }

      it 'raises ArgumentError' do
        expect { OcflS3Service.new(service_def, app_manager) }
          .to raise_error(ArgumentError, /unknown storage location/)
      end
    end

    context 'when the destination is a filesystem location rather than S3' do
      let(:fs_dest) { build(:storage_location, path: path_src_dir, metadata_path: md_src_dir) }
      let(:loc_manager) { instance_double('Longleaf::StorageLocationManager',
          locations: { 'dest_loc' => fs_dest }) }
      let(:service_def) { make_service_def(['dest_loc']) }

      it 'raises ArgumentError' do
        expect { OcflS3Service.new(service_def, app_manager) }
          .to raise_error(ArgumentError, /not of type 's3'/)
      end
    end
  end

  # ── is_applicable? ────────────────────────────────────────────────────────

  describe '.is_applicable?' do
    let(:dest) { build(:s3_storage_location, metadata_path: md_dest_dir) }
    let(:service) { OcflS3Service.new(make_service_def(['dest_loc']), app_manager) }

    it 'returns true for PRESERVE' do
      expect(service.is_applicable?(PRESERVE_EVENT)).to be true
    end

    it 'returns false for REGISTER' do
      expect(service.is_applicable?(Longleaf::EventNames::REGISTER)).to be false
    end

    it 'returns false for unknown events' do
      expect(service.is_applicable?('something_else')).to be false
    end
  end

  # ── perform ───────────────────────────────────────────────────────────────

  describe '.perform' do
    let(:dest)         { build(:s3_storage_location, metadata_path: md_dest_dir) }
    let(:service)      { OcflS3Service.new(make_service_def(['dest_loc']), app_manager) }
    let(:source_loc)   { build_ocfl_location }
    let(:file_rec)     { make_file_record(ocfl_object_path, source_loc) }

    before { setup_ocfl_fixture }

    def retrieve_uploaded_keys
        dest.s3_client.api_requests
          .select { |r| r[:operation_name] == :put_object }
          .map { |r| r[:params][:key] }
    end

    context 'when the source is not an OCFL storage location' do
      let(:fs_loc) { build(:storage_location, path: path_src_dir, metadata_path: md_src_dir) }

      it 'raises PreservationServiceError' do
        fr = build(:file_record, file_path: ocfl_object_path,
          storage_location: fs_loc, physical_path: ocfl_object_path)
        expect { service.perform(fr, PRESERVE_EVENT) }
          .to raise_error(PreservationServiceError, /only supports replication from OCFL/)
      end
    end

    context 'when the OCFL object directory does not exist' do
      it 'raises PreservationServiceError' do
        fr = make_file_record('/does/not/exist', source_loc)
        expect { service.perform(fr, PRESERVE_EVENT) }
          .to raise_error(PreservationServiceError, /does not exist/)
      end
    end

    context 'when the destination bucket is unavailable' do
      before { dest.s3_client.stub_responses(:head_bucket, 'NotFound') }

      it 'raises StorageLocationUnavailableError' do
        expect { service.perform(file_rec, PRESERVE_EVENT) }
          .to raise_error(Longleaf::StorageLocationUnavailableError)
      end
    end

    context 'when the S3 upload fails' do
      before { dest.s3_client.stub_responses(:put_object, 'InternalError') }

      it 'raises PreservationServiceError' do
        expect { service.perform(file_rec, PRESERVE_EVENT) }
          .to raise_error(PreservationServiceError, /Failed to transfer/)
      end
    end

    context 'full upload of a fresh OCFL object (no prior S3 objects)' do
      before do
        # Ensure head_object always returns 404 so every file is uploaded
        dest.s3_client.stub_responses(:head_object, 'NoSuchKey')
      end
      it 'uploads every file in the object directory' do
        service.perform(file_rec, PRESERVE_EVENT)

        uploaded_keys = retrieve_uploaded_keys

        local_files = []
        Find.find(ocfl_object_path) do |p|
          next if File.directory?(p)
          rel = p.sub("#{ocfl_object_path}/", '')
          local_files << "#{s3_object_prefix}/#{rel}"
        end

        expect(uploaded_keys).to match_array(local_files)
      end

      it 'issues a head_object check for every file' do
        service.perform(file_rec, PRESERVE_EVENT)

        head_keys = dest.s3_client.api_requests
          .select { |r| r[:operation_name] == :head_object }
          .map { |r| r[:params][:key] }

        local_files = []
        Find.find(ocfl_object_path) do |p|
          next if File.directory?(p)
          rel = p.sub("#{ocfl_object_path}/", '')
          local_files << "#{s3_object_prefix}/#{rel}"
        end

        expect(head_keys).to match_array(local_files)
      end
    end

    context 'skip behaviour based on file type' do
      # Pre-populate S3 with stubbed head_object responses for selected keys.
      def stub_s3_object_exists(s3_key, local_path)
        md5 = Digest::MD5.file(local_path).hexdigest
        dest.s3_client.stub_responses(:head_object,
          ->(context) {
            context.params[:key] == s3_key ?
              { content_length: File.size(local_path), etag: "\"#{md5}\"" } :
              'NoSuchKey'
          }
        )
      end

      context 'vN/ file that already exists unchanged in S3' do
        let(:version_inv_local) { File.join(ocfl_object_path, 'v1', 'inventory.json') }
        let(:s3_key)  { "#{s3_object_prefix}/v1/inventory.json" }

        before do
          # Respond with some non-nil content_length; ETag is irrelevant for vN/ files
          dest.s3_client.stub_responses(:head_object,
            ->(context) {
              context.params[:key] == s3_key ?
                { content_length: File.size(version_inv_local), etag: '"irrelevant"' } :
                'NoSuchKey'
            }
          )
        end

        it 'skips the upload without computing an MD5' do
          service.perform(file_rec, PRESERVE_EVENT)

          uploaded_keys = retrieve_uploaded_keys

          expect(uploaded_keys).not_to include(s3_key)
        end
      end

      context 'root inventory.json that already exists with matching ETag' do
        let(:root_inv_local) { File.join(ocfl_object_path, 'inventory.json') }
        let(:s3_key)         { "#{s3_object_prefix}/inventory.json" }

        before { stub_s3_object_exists(s3_key, root_inv_local) }

        it 'skips the upload' do
          service.perform(file_rec, PRESERVE_EVENT)

          uploaded_keys = retrieve_uploaded_keys

          expect(uploaded_keys).not_to include(s3_key)
        end
      end

      context 'root inventory.json.sha512 whose content changed but size is identical' do
        let(:sidecar_local) { File.join(ocfl_object_path, 'inventory.json.sha512') }
        let(:s3_key)        { "#{s3_object_prefix}/inventory.json.sha512" }

        before do
          original_md5 = Digest::MD5.file(sidecar_local).hexdigest
          stale_md5 = original_md5.tr('0-9a-f', 'a-f0-9') # shift every digit by 10 to ensure the "old" md5 is different
          dest.s3_client.stub_responses(:head_object,
            ->(context) {
              context.params[:key] == s3_key ?
                { content_length: File.size(sidecar_local), etag: "\"#{stale_md5}\"" } :
                'NoSuchKey'
            }
          )
        end

        it 're-uploads the sidecar because the ETag differs' do
          service.perform(file_rec, PRESERVE_EVENT)

          uploaded_keys = retrieve_uploaded_keys

          expect(uploaded_keys).to include(s3_key)
        end
      end

      context 'root inventory.json with a multipart ETag and unchanged size' do
        let(:root_inv_local) { File.join(ocfl_object_path, 'inventory.json') }
        let(:s3_key)         { "#{s3_object_prefix}/inventory.json" }

        before do
          dest.s3_client.stub_responses(:head_object,
            ->(context) {
              context.params[:key] == s3_key ?
                # Multipart ETag because it contains a - character
                { content_length: File.size(root_inv_local), etag: '"abc123-3"' } :
                'NoSuchKey'
            }
          )
        end

        it 'skips the upload using size as a fallback' do
          service.perform(file_rec, PRESERVE_EVENT)

          uploaded_keys = retrieve_uploaded_keys

          expect(uploaded_keys).not_to include(s3_key)
        end
      end

      context 'root inventory.json with a multipart ETag and changed size' do
        let(:root_inv_local) { File.join(ocfl_object_path, 'inventory.json') }
        let(:s3_key)         { "#{s3_object_prefix}/inventory.json" }

        before do
          dest.s3_client.stub_responses(:head_object,
            ->(context) {
              context.params[:key] == s3_key ?
                { content_length: File.size(root_inv_local) - 8, etag: '"abc123-3"' } :
                'NoSuchKey'
            }
          )
        end

        it 're-uploads the inventory because the size differs' do
          service.perform(file_rec, PRESERVE_EVENT)

          uploaded_keys = retrieve_uploaded_keys

          expect(uploaded_keys).to include(s3_key)
        end
      end
    end

    context 'mutable head cleanup' do
      let(:source_loc)   { build_ocfl_location(mutable_head: true) }
      let(:mutable_head_dir) do
        dir = File.join(ocfl_object_path, 'extensions', '0005-mutable-head')
        FileUtils.mkdir_p(File.join(dir, 'head', 'content', 'r1'))
        FileUtils.mkdir_p(File.join(dir, 'revisions'))
        dir
      end

      before do
        # Ensure the mutable head directory exists
        mutable_head_dir
      end

      context 'when a stale mutable head object exists in S3 but not locally' do
        let(:stale_key) { "#{s3_object_prefix}/extensions/0005-mutable-head/head/content/r1/old_file.bin" }
        let(:mutable_head_prefix) { "#{s3_object_prefix}/extensions/0005-mutable-head/" }

        before do
          # Stub list_objects_v2 to return the stale mutable head key under the prefix
          dest.s3_client.stub_responses(:list_objects_v2,
            ->(context) {
              if context.params[:prefix] == mutable_head_prefix
                {
                  contents: [{ key: stale_key, size: 100, etag: '"abc"' }],
                  is_truncated: false
                }
              else
                { contents: [], is_truncated: false }
              end
            }
          )
        end

        it 'deletes the stale S3 object' do
          service.perform(file_rec, PRESERVE_EVENT)

          delete_requests = dest.s3_client.api_requests
            .select { |r| r[:operation_name] == :delete_objects }

          deleted_keys = delete_requests.flat_map { |r| r[:params][:delete][:objects].map { |o| o[:key] } }
          expect(deleted_keys).to include(stale_key)
          expect(deleted_keys.length()).to eq 1
        end
      end

      context 'when a mutable head file exists both locally and in S3' do
        let(:local_head_file) do
          path = File.join(mutable_head_dir, 'head', 'content', 'r1', 'current_file.bin')
          File.write(path, 'active content')
          path
        end
        let(:head_file_rel)  { "extensions/0005-mutable-head/head/content/r1/current_file.bin" }
        let(:head_file_key)  { "#{s3_object_prefix}/#{head_file_rel}" }
        let(:mutable_head_prefix) { "#{s3_object_prefix}/extensions/0005-mutable-head/" }

        before do
          local_head_file # create the file
          dest.s3_client.stub_responses(:list_objects_v2,
            ->(context) {
              if context.params[:prefix] == mutable_head_prefix
                {
                  contents: [{ key: head_file_key, size: File.size(local_head_file), etag: '"xyz"' }],
                  is_truncated: false
                }
              else
                { contents: [], is_truncated: false }
              end
            }
          )
        end

        it 'does not delete the object that still exists locally' do
          service.perform(file_rec, PRESERVE_EVENT)

          delete_requests = dest.s3_client.api_requests
            .select { |r| r[:operation_name] == :delete_objects }
          expect(delete_requests).to be_empty
        end
      end

      context 'when a stale object exists outside the mutable head subtree' do
        let(:stale_version_key) { "#{s3_object_prefix}/v99/inventory.json" }
        # Populated multiple head file so that it doesn't get detected as deleted
        let!(:local_mutable_file) do
          path = File.join(ocfl_object_path, 'extensions', '0005-mutable-head', 'head', 'inventory.json')
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, '{}')
          path
        end
        let(:present_mutable_key) { "#{s3_object_prefix}/extensions/0005-mutable-head/head/inventory.json" }
        let(:mutable_head_prefix) { "#{s3_object_prefix}/extensions/0005-mutable-head/" }

        before do
          dest.s3_client.stub_responses(:list_objects_v2,
            ->(context) {
              if context.params[:prefix] == mutable_head_prefix
                {
                  contents: [{ key: present_mutable_key, size: 2, etag: '"aaa"' }],
                  is_truncated: false
                }
              else
                { contents: [], is_truncated: false }
              end
            }
          )
        end

        it 'does not delete objects outside the mutable head prefix' do
          service.perform(file_rec, PRESERVE_EVENT)

          delete_requests = dest.s3_client.api_requests
            .select { |r| r[:operation_name] == :delete_objects }
          expect(delete_requests).to be_empty
        end
      end
    end

    context 'when the source location does not have mutable head enabled' do
      let(:stale_key) { "#{s3_object_prefix}/extensions/0005-mutable-head/head/content/r1/old_file.bin" }
      let(:mutable_head_prefix) { "#{s3_object_prefix}/extensions/0005-mutable-head/" }

      before do
        dest.s3_client.stub_responses(:list_objects_v2,
          ->(context) {
            if context.params[:prefix] == mutable_head_prefix
              {
                contents: [{ key: stale_key, size: 100, etag: '"abc"' }],
                is_truncated: false
              }
            else
              { contents: [], is_truncated: false }
            end
          }
        )
      end

      it 'does not perform mutable head cleanup' do
        service.perform(file_rec, PRESERVE_EVENT)

        list_requests = dest.s3_client.api_requests
          .select { |r| r[:operation_name] == :list_objects_v2 }
        delete_requests = dest.s3_client.api_requests
          .select { |r| r[:operation_name] == :delete_objects }

        expect(list_requests).to be_empty
        expect(delete_requests).to be_empty
      end
    end

    context 'with multiple destinations' do
      let(:md_dest_dir2) { Dir.mktmpdir('dest2_metadata') }
      let(:dest2)        { build(:s3_storage_location,
          path: 'https://anotherbucket.s3-amazonaws.com/',
          metadata_path: md_dest_dir2) }
      let(:loc_manager)  { instance_double('Longleaf::StorageLocationManager',
          locations: { 'dest_loc' => dest, 'dest_loc2' => dest2 }) }
      let(:service)      { OcflS3Service.new(make_service_def(['dest_loc', 'dest_loc2']), app_manager) }

      after { FileUtils.rm_rf(md_dest_dir2) }

      it 'uploads to both destinations' do
        service.perform(file_rec, PRESERVE_EVENT)

        [dest, dest2].each do |d|
          uploaded = d.s3_client.api_requests
            .select { |r| r[:operation_name] == :put_object }
          expect(uploaded).not_to be_empty
        end
      end
    end
  end

  describe '.versioned_object_file?' do
    let(:dest) { build(:s3_storage_location, metadata_path: md_dest_dir) }
    let(:service) { OcflS3Service.new(make_service_def(['dest_loc']), app_manager) }

    { 'v1/inventory.json'                                          => true,
      'v2/content/r1/foo.txt'                                      => true,
      'v10/inventory.json.sha512'                                  => true,
      'inventory.json'                                             => false,
      'inventory.json.sha512'                                      => false,
      '0=ocfl_object_1.1'                                          => false,
      'extensions/0005-mutable-head/head/inventory.json'           => false,
      'extensions/0005-mutable-head/head/content/r1/file.txt'      => false,
      'extensions/0005-mutable-head/revisions/r1'                  => false,
      'extensions/0005-mutable-head/root-inventory.json.sha512'    => false
    }.each do |path, expected|
      it "returns #{expected} for '#{path}'" do
        expect(service.send(:versioned_object_file?, path)).to eq(expected)
      end
    end
  end
end
