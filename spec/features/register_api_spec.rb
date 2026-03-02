require 'spec_helper'
require 'rack/test'
require 'json'
require 'digest'
require 'fileutils'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/services/metadata_serializer'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/web/app'

describe 'POST /api/register' do
  include Rack::Test::Methods
  include Longleaf::FileHelpers

  ConfigBuilder ||= Longleaf::ConfigBuilder

  # Use the Roda App class directly as a Rack app; no freeze so we can inject
  # test app_manager state between examples.
  def app
    Longleaf::Web::App
  end

  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir)   { Dir.mktmpdir('metadata') }

  after do
    FileUtils.remove_dir(md_dir)
    FileUtils.remove_dir(path_dir)
    # Reset app_manager so tests stay isolated
    Longleaf::Web::App.app_manager = nil
  end

  # Build a real ApplicationConfigManager from a config file and inject it into
  # the App class, mirroring what happens at server boot with LONGLEAF_CFG.
  def load_config(config_path)
    manager = Longleaf::ApplicationConfigDeserializer.deserialize(config_path)
    Longleaf::Web::App.app_manager = manager
    manager
  end

  def post_register(params = {})
    post '/api/register', params.to_json, 'CONTENT_TYPE' => 'application/json'
  end

  def response_body
    JSON.parse(last_response.body)
  end

  # --- metadata helpers ---

  def metadata_record_path(file_path)
    File.join(md_dir, File.basename(file_path) + Longleaf::MetadataSerializer::metadata_suffix)
  end

  def metadata_exists?(file_path)
    File.exist?(metadata_record_path(file_path))
  end

  def get_metadata_record(file_path)
    Longleaf::MetadataDeserializer.deserialize(file_path: metadata_record_path(file_path))
  end

  # =========================================================================

  context 'when application configuration is not loaded' do
    before { Longleaf::Web::App.app_manager = nil }

    it 'returns 503' do
      post_register(file: '/some/path')
      expect(last_response.status).to eq 503
    end
  end

  # =========================================================================

  context 'with a valid application configuration' do
    let!(:config_path) do
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file
    end

    before { load_config(config_path) }

    context 'when no file selection parameter is provided' do
      it 'returns 400' do
        post_register
        expect(last_response.status).to eq 400
      end
    end

    context 'when the file does not exist' do
      let(:missing_path) { File.join(path_dir, 'no_such_file.txt') }

      it 'returns 500' do
        post_register(file: missing_path)
        expect(last_response.status).to eq 500
      end
    end

    context 'when the file is not in a known storage location' do
      let!(:outside_file) { create_test_file }  # created outside path_dir

      after { File.delete(outside_file) if File.exist?(outside_file) }

      it 'returns 500' do
        post_register(file: outside_file)
        expect(last_response.status).to eq 500
      end
    end

    context 'register a single file' do
      let!(:file_path) { create_test_file(dir: path_dir) }

      it 'returns 202 and creates metadata' do
        post_register(file: file_path)

        expect(last_response.status).to eq 202
        expect(response_body['status']).to eq 'success'
        expect(metadata_exists?(file_path)).to be true
      end
    end

    context 'register multiple files in a single request' do
      let!(:file_path)  { create_test_file(dir: path_dir) }
      let!(:file_path2) { create_test_file(dir: path_dir, name: 'another_file', content: 'more content') }

      it 'returns 202 and creates metadata for each file' do
        post_register(file: "#{file_path},#{file_path2}")

        expect(last_response.status).to eq 202
        expect(metadata_exists?(file_path)).to be true
        expect(metadata_exists?(file_path2)).to be true
      end
    end

    context 'register an already-registered file' do
      let!(:file_path) { create_test_file(dir: path_dir) }

      before { post_register(file: file_path) }

      it 'returns 500 on a second request without force' do
        post_register(file: file_path)
        expect(last_response.status).to eq 500
      end

      it 'returns 202 on a second request with force: true' do
        post_register(file: file_path, force: 'true')
        expect(last_response.status).to eq 202
        expect(metadata_exists?(file_path)).to be true
      end
    end

    context 'register a file with explicit checksums' do
      let(:content)    { 'deterministic content' }
      let!(:file_path) { create_test_file(dir: path_dir, content: content) }
      let(:md5_digest) { Digest::MD5.hexdigest(content) }

      it 'returns 202 and persists the checksum in metadata' do
        post_register(file: file_path, checksums: "md5:#{md5_digest}")

        expect(last_response.status).to eq 202
        md_rec = get_metadata_record(file_path)
        expect(md_rec.checksums['md5']).to eq md5_digest
      end
    end

    context 'register a file with a separate physical path' do
      let!(:physical_file) { create_test_file(dir: path_dir) }
      let(:logical_path)   { File.join(path_dir, 'logical_name') }

      it 'returns 202 and stores the physical path in metadata' do
        post_register(file: logical_path, physical_path: physical_file)

        expect(last_response.status).to eq 202
        md_rec = get_metadata_record(logical_path)
        expect(md_rec.physical_path).to eq physical_file
      end
    end
  end
end
