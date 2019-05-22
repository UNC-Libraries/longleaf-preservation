require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/system_config_builder'
require 'longleaf/indexing/sequel_index_driver'
require 'longleaf/specs/metadata_builder'
require 'longleaf/services/application_config_deserializer'
require 'tempfile'
require 'fileutils'
require 'sequel'

describe 'reindex command', :type => :aruba do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  SysConfigBuilder ||= Longleaf::SystemConfigBuilder
  MetadataBuilder ||= Longleaf::MetadataBuilder

  SECONDS_IN_DAY ||= 60 * 60 * 24

  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir) { Dir.mktmpdir('metadata') }
  let(:lib_dir) { make_test_dir(name: 'lib_dir') }

  let(:db_file) { create_test_file(name: 'index.db', content: '') }
  let(:config_file) { create_test_file(name: 'config.yml') }

  let!(:work_script_file) { create_work_class(lib_dir, 'PresService', 'pres_service.rb') }

  let(:sys_config) {
    SysConfigBuilder.new
      .with_index('amalgalite', "amalgalite://#{db_file}")
      .get
  }

  before :all do
    Sequel.default_timezone = :utc
  end

  after do
    FileUtils.rm_rf([md_dir, path_dir, lib_dir])
    FileUtils.rm([db_file, config_file])
    $LOAD_PATH.delete(lib_dir)
  end

  context 'no index configured' do
    let(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: work_script_file, frequency: "1 minute")
        .map_services('loc1', 'serv1')
        .write_to_yaml_file(config_file)
    }

    let(:app_config) { Longleaf::ApplicationConfigDeserializer.deserialize(config_path) }

    before do
      run_simple("longleaf reindex -c #{config_path}", fail_on_error: false)
    end

    it 'exits with failure' do
      expect(last_command_started).to have_output(/Cannot perform reindex, no index is configured/)
      expect(last_command_started).to have_exit_status(1)
    end
  end

  context 'one storage location with service' do
    let(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: work_script_file, frequency: "1 minute")
        .map_services('loc1', 'serv1')
        .with_system(sys_config)
        .write_to_yaml_file(config_file)
    }

    let(:app_config) { Longleaf::ApplicationConfigDeserializer.deserialize(config_path) }
    let(:index_manager) { app_config.index_manager }

    let(:storage_loc) { app_config.location_manager.locations['loc1'] }

    context 'no registered files' do
      before do
        index_manager.setup_index
      end

      context 'reindex' do
        before do
          @last_reindexed = get_index_state[:last_reindexed]
          run_simple("longleaf reindex -c #{config_path}", fail_on_error: false)
        end

        it 'succeeds but indexes nothing' do
          expect(last_command_started).to have_output(/SUCCESS: Completed reindexing, 0 successful/)
          expect(last_command_started).to have_exit_status(0)
        end
      end
    end

    context 'one registered file' do
      before do
        index_manager.setup_index
      end

      let!(:file_rec1) { create_index_file_rec(storage_loc, 'serv1', days_from_now(-1)) }

      context 'full reindex' do
        before do
          @last_reindexed = get_index_state[:last_reindexed]
          run_simple("longleaf reindex -c #{config_path}", fail_on_error: false)
        end

        it 'reindexes the file' do
          expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec1.path}/)
          expect(last_command_started).to have_exit_status(0)

          # Ensure that the index state was updated
          reindexed_time = get_index_state[:last_reindexed]
          expect(reindexed_time).to be_within(5).of (Time.now.utc)
          expect(@last_reindexed).to_not eq reindexed_time
        end
      end

      context 'with if_stale flag, non-stale index' do
        before do
          run_simple("longleaf reindex -c #{config_path} --if_stale", fail_on_error: false)
        end

        it 'completes with no action taken' do
          expect(last_command_started).to have_output(/Index is not stale, performing no action/)
          expect(last_command_started).to have_exit_status(0)
        end
      end

      context 'with if_stale flag, after service frequency change' do
        before do
          ConfigBuilder.new
              .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
              .with_service(name: 'serv1', work_script: work_script_file, frequency: "1 day")
              .map_services('loc1', 'serv1')
              .with_system(sys_config)
              .write_to_yaml_file(config_path)

          run_simple("longleaf reindex -c #{config_path} --if_stale", fail_on_error: false)
        end

        it 'reindexes the file' do
          expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec1.path}/)
          expect(last_command_started).to have_exit_status(0)

          # Frequency of the service changed to daily, so next run should be right about now
          expect(get_timestamp_from_index(file_rec1)).to be_within(5).of (Time.now.utc)
        end

        context 'reindex again with if_stale' do
          before do
            run_simple("longleaf reindex -c #{config_path} --if_stale", fail_on_error: false)
          end

          it 'completes with no action taken' do
            expect(last_command_started).to have_output(/Index is not stale, performing no action/)
            expect(last_command_started).to have_exit_status(0)
          end
        end
      end
    end

    context 'multiple registered files' do
      before do
        index_manager.setup_index
      end

      let!(:file_rec1) { create_index_file_rec(storage_loc, 'serv1', days_from_now(-1)) }
      let!(:file_rec2) { create_index_file_rec(storage_loc, 'serv1', days_from_now) }
      let(:sub_dir) { make_test_dir(name: 'subdir', parent: path_dir) }
      let!(:file_rec3) { create_index_file_rec(storage_loc, 'serv1', days_from_now, sub_dir) }

      context 'normal reindex' do
        before do
          run_simple("longleaf reindex -c #{config_path}", fail_on_error: false)
        end

        it 'reindexes the files' do
          expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec1.path}/)
          expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec2.path}/)
          expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec3.path}/)
          expect(last_command_started).to have_output(/SUCCESS: Completed reindexing, 3 successful/)
          expect(last_command_started).to have_exit_status(0)
        end
      end

      context 'one file with invalid metadata' do
        before do
          File.open(file_rec2.metadata_path, 'a') { |f| f.write("busted") }

          run_simple("longleaf reindex -c #{config_path}", fail_on_error: false)
        end

        it 'reindexes two of the files, fails one' do
          expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec1.path}/)
          expect(last_command_started).to have_output(/FAILURE: Failed to reindex #{file_rec2.path}: Failed to parse metadata file #{file_rec2.metadata_path}/)
          expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec3.path}/)
          expect(last_command_started).to have_output(/SUCCESS: Completed reindexing, 2 successful, 1 failed/)
          expect(last_command_started).to have_exit_status(2)
        end
      end

      context 'one file removed without updating index' do
        before do
          FileUtils.rm([file_rec2.path, file_rec2.metadata_path])

          run_simple("longleaf reindex -c #{config_path}", fail_on_error: false)
        end

        it 'cleans up the removed file from index' do
          expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec1.path}/)
          expect(last_command_started).to_not have_output(/SUCCESS: Reindexed #{file_rec2.path}/)
          expect(last_command_started).to have_output(/Clearing '#{file_rec2.path}' from index, file is no longer present/)
          expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec3.path}/)
          expect(last_command_started).to have_output(/SUCCESS: Completed reindexing, 2 successful/)
          expect(last_command_started).to have_exit_status(0)

          expect(get_row_from_index(file_rec1)).to_not be_nil
          expect(get_row_from_index(file_rec2)).to be_nil
          expect(get_row_from_index(file_rec3)).to_not be_nil
        end
      end
    end

    context 'files previously registered by not indexed' do
      let!(:file_rec1) { create_file_rec(storage_loc, 'serv1', days_from_now(-1)) }
      let!(:file_rec2) { create_file_rec(storage_loc, 'serv1', days_from_now) }

      before do
        index_manager.setup_index
        run_simple("longleaf reindex -c #{config_path}", fail_on_error: false)
      end

      it 'indexes the files' do
        expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec1.path}/)
        expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec2.path}/)
        expect(last_command_started).to have_exit_status(0)

        # verify that the record was indexed, accounting for the frequency delay
        expect(get_timestamp_from_index(file_rec2)).to be_within(240).of (Time.now.utc)
      end
    end
  end

  context 'multiple storage locations' do
    let(:path_dir2) { Dir.mktmpdir('path2') }
    let(:md_dir2) { Dir.mktmpdir('metadata2') }

    after do
      FileUtils.rm_rf([md_dir2, path_dir2])
    end

    let(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_location(name: 'loc2', path: path_dir2, md_path: md_dir2)
        .with_service(name: 'serv1', work_script: work_script_file, frequency: "1 minute")
        .map_services('loc1', 'serv1')
        .map_services('loc2', 'serv1')
        .with_system(sys_config)
        .write_to_yaml_file(config_file)
    }

    let(:app_config) { Longleaf::ApplicationConfigDeserializer.deserialize(config_path) }
    let(:index_manager) { app_config.index_manager }

    let(:storage_loc1) { app_config.location_manager.locations['loc1'] }
    let(:storage_loc2) { app_config.location_manager.locations['loc2'] }

    before do
      index_manager.setup_index
    end

    context 'one file in each location' do
      let!(:file_rec1) { create_file_rec(storage_loc1, 'serv1', days_from_now(-1)) }
      let!(:file_rec2) { create_file_rec(storage_loc2, 'serv1', days_from_now) }

      before do
        run_simple("longleaf reindex -c #{config_path}", fail_on_error: false)
      end

      it 'reindexes files in both locations' do
        expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec1.path}/)
        expect(last_command_started).to have_output(/SUCCESS: Reindexed #{file_rec2.path}/)
        expect(last_command_started).to have_output(/SUCCESS: Completed reindexing, 2 successful/)
        expect(last_command_started).to have_exit_status(0)
      end
    end
  end

  def db_conn
    @conn = Sequel.connect("amalgalite://#{db_file}") if @conn.nil?
    @conn
  end

  def get_timestamp_from_index(file_rec)
    result = db_conn[Longleaf::SequelIndexDriver::PRESERVE_TBL].where(file_path: file_rec.path).select(:service_time).first

    result.nil? ? nil : result[:service_time]
  end

  def get_row_from_index(file_rec)
    db_conn[Longleaf::SequelIndexDriver::PRESERVE_TBL].where(file_path: file_rec.path).select.first
  end

  def get_index_state
    db_conn[Longleaf::SequelIndexDriver::INDEX_STATE_TBL].select.first
  end

  def days_from_now(offset = 0)
    Time.now.utc + SECONDS_IN_DAY * offset
  end

  def create_file_rec(storage_loc, with_service = nil, with_timestamp = nil, dest_path = nil)
    if dest_path.nil?
      file_path = create_test_file(dir: storage_loc.path)
    else
      file_path = create_test_file(dir: dest_path)
    end
    file_rec = build(:file_record, file_path: file_path, storage_location: storage_loc)

    md_builder = MetadataBuilder.new(file_path: file_path)
    unless with_service.nil?
      md_builder.with_service(with_service, timestamp: with_timestamp)
    end
    md_builder.write_to_yaml_file(file_rec: file_rec)

    file_rec
  end

  def create_index_file_rec(storage_loc, with_service = nil, with_timestamp = nil, dest_path = nil)
    file_rec = create_file_rec(storage_loc, with_service, with_timestamp, dest_path)

    app_config.index_manager.index(file_rec)
    file_rec
  end
end
