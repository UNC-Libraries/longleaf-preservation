require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/config_builder'
require 'longleaf/services/metadata_serializer'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/specs/file_helpers'
require 'tempfile'
require 'yaml'
require 'fileutils'

describe 'deregister', :type => :aruba do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir) { Dir.mktmpdir('metadata') }

  after do
    FileUtils.rm_rf([md_dir, path_dir])
  end

  context 'with valid configuration' do
    let!(:config_path) {
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file
    }
    let(:file_path) { create_test_file(dir: path_dir) }

    context 'empty file path' do
      before do
        run_command_and_stop("longleaf deregister -c #{config_path} -f ''", fail_on_error: false)
      end

      it 'rejects missing file path value' do
        expect(last_command_started).to have_output(/Must provide either file paths or storage locations/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'file does not exist' do
      before do
        File.delete(file_path)

        run_command_and_stop("longleaf deregister -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'rejects file which does not exist' do
        puts last_command_started.stderr
        expect(last_command_started).to have_output(
          /FAILURE deregister: File .* does not exist./)
        expect(last_command_started).to have_exit_status(1)
      end
    end
    
    context 'file registered but does not exist' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f #{file_path}", fail_on_error: false)
        
        File.delete(file_path)

        run_command_and_stop("longleaf deregister -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'deregisters the file' do
        expect(last_command_started).to have_output(/SUCCESS deregister #{file_path}/)
        expect(file_deregistered?(file_path, md_dir)).to be true
        expect(last_command_started).to have_exit_status(0)
        expect(File).not_to exist(file_path)
      end
    end
    
    context 'deregister from non-existent list' do
      let!(:from_list_file) { File.join(path_dir, "path", "doesnt", "exist.txt") }
      
      before do
        run_command_and_stop("longleaf deregister -c #{config_path} -l '#{from_list_file}'", fail_on_error: false)
      end
      
      it 'rejects list which does not exist' do
        expect(last_command_started).to have_output(
          /FAILURE: Specified list file does not exist: #{from_list_file}/)
        expect(last_command_started).to have_exit_status(1)
      end
    end
    
    context 'from list parameter empty' do
      before do
        run_command_and_stop("longleaf deregister -c #{config_path} -l ''", fail_on_error: false)
      end
      
      it 'rejects value' do
        expect(last_command_started).to have_output(
          /FAILURE: List parameter must not be empty/)
        expect(last_command_started).to have_exit_status(1)
      end
    end
    
    context 'providing -l and -f' do
      before do
        run_command_and_stop("longleaf deregister -c #{config_path} -f '#{file_path}' -l '#{file_path}'", fail_on_error: false)
      end
      
      it 'rejects parameters' do
        expect(last_command_started).to have_output(
          /FAILURE: Only one of the following selection options may be provided: -l, -f, -s/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'file not in a registered storage location' do
      before do
        test_file = create_test_file(name: 'not_in_path')

        run_command_and_stop("longleaf deregister -c #{config_path} -f '#{test_file}'", fail_on_error: false)
      end

      it 'outputs failure to find storage location' do
        expect(last_command_started).to have_output(
          /FAILURE deregister: Path .* is not from a known storage location/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'file not registered' do
      before do
        run_command_and_stop("longleaf deregister -c #{config_path} -f '#{file_path}'", fail_on_error: false)
      end

      it 'outputs failure to find storage location' do
        expect(last_command_started).to have_output(
          /FAILURE deregister: File #{file_path} is not registered./)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'file is registered' do
      before do
        run_command_and_stop("longleaf register -c #{config_path} -f #{file_path}", fail_on_error: false)
      end

      context 'deregister file' do
        before do
          run_command_and_stop("longleaf deregister -c #{config_path} -f #{file_path}", fail_on_error: false)
        end

        it 'deregisters the file' do
          expect(last_command_started).to have_output(/SUCCESS deregister #{file_path}/)
          expect(file_deregistered?(file_path, md_dir)).to be true
          expect(last_command_started).to have_exit_status(0)
        end
      end

      context 'deregister file more than once' do
        before do
          run_command_and_stop("longleaf deregister -c #{config_path} -f '#{file_path}'", fail_on_error: false)
          run_command_and_stop("longleaf deregister -c #{config_path} -f '#{file_path}'", fail_on_error: false)
        end

        it 'rejects registering file' do
          # File should be registered by first call
          expect(file_deregistered?(file_path, md_dir)).to be true
          # Only testing output from second command, so no registered message visible
          expect(last_command_started).to_not have_output(/SUCCESS.*/)
          expect(last_command_started).to have_output(
              /Unable to deregister '#{file_path}', it is already deregistered/)
          expect(last_command_started).to have_exit_status(1)
        end
      end

      context 'deregister file more than once with force flag' do
        before do
          run_command_and_stop("longleaf deregister -c #{config_path} -f '#{file_path}'", fail_on_error: false)
          run_command_and_stop("longleaf deregister -c #{config_path} -f '#{file_path}' --force", fail_on_error: false)
        end

        it 'deregisters the file' do
          expect(last_command_started).to have_output(/SUCCESS deregister #{file_path}/)
          expect(file_deregistered?(file_path, md_dir)).to be true
          expect(last_command_started).to have_exit_status(0)
        end
      end

      context 'deregister multiple files' do
        let(:file_path2) { create_test_file(dir: path_dir, name: 'another_file') }

        context 'only one file is registered' do
          before do
            run_command_and_stop("longleaf deregister -c #{config_path} -f '#{file_path},#{file_path2}'", fail_on_error: false)
          end

          it 'registers one file, fails the other' do
            expect(last_command_started).to have_output(/SUCCESS deregister #{file_path}/)
            expect(file_deregistered?(file_path, md_dir)).to be true
            expect(last_command_started).to have_output(
                /FAILURE deregister: File #{file_path2} is not registered./)
            expect(file_deregistered?(file_path2, md_dir)).to be false
            expect(last_command_started).to have_exit_status(2)
          end
        end

        context 'all files are registered' do
          before do
            run_command_and_stop("longleaf register -c #{config_path} -f #{file_path2}", fail_on_error: false)

            run_command_and_stop("longleaf deregister -c #{config_path} -f '#{file_path},#{file_path2}'", fail_on_error: false)
          end

          it 'deregisters both files' do
            expect(last_command_started).to have_output(/SUCCESS deregister #{file_path}/)
            expect(file_deregistered?(file_path, md_dir)).to be true
            expect(last_command_started).to have_output(/SUCCESS deregister #{file_path2}/)
            expect(file_deregistered?(file_path2, md_dir)).to be true
            expect(last_command_started).to have_exit_status(0)
          end
        end
        
        context 'deregister multiple files from file list' do
          let!(:from_list_file) { create_test_file(dir: path_dir, name: "file_list.txt", content:
                       "#{file_path}\n" +
                       "#{file_path2}") }
          
          before do
            run_command_and_stop("longleaf register -c #{config_path} -f #{file_path2}", fail_on_error: false)

            run_command_and_stop("longleaf deregister -c #{config_path} -l '#{from_list_file}'", fail_on_error: false)
          end
          
          it 'deregisters both files' do
            expect(last_command_started).to have_output(/SUCCESS deregister #{file_path}/)
            expect(file_deregistered?(file_path, md_dir)).to be true
            expect(last_command_started).to have_output(/SUCCESS deregister #{file_path2}/)
            expect(file_deregistered?(file_path2, md_dir)).to be true
            expect(last_command_started).to have_exit_status(0)
          end
        end
        
        context 'deregister single file from STDIN list' do
          let!(:from_list_file) { create_test_file(dir: path_dir, name: "file_list.txt", content:
                       "#{file_path}") }
          
          before do
            run_command_and_stop("longleaf register -c #{config_path} -f #{file_path2}", fail_on_error: false)

            run_command("longleaf deregister -c #{config_path} -l @-", fail_on_error: false)
            pipe_in_file(from_list_file)
            close_input
          end
          
          it 'deregisters one file' do
            expect(last_command_started).to have_output(/SUCCESS deregister #{file_path}/)
            expect(file_deregistered?(file_path, md_dir)).to be true
            expect(file_deregistered?(file_path2, md_dir)).to be false
            expect(last_command_started).to have_exit_status(0)
          end
        end
        
        context 'deregister multiple files from STDIN list' do
          let!(:from_list_file) { create_test_file(dir: path_dir, name: "file_list.txt", content:
                       "#{file_path}\n" +
                       "#{file_path2}") }
          
          before do
            run_command_and_stop("longleaf register -c #{config_path} -f #{file_path2}", fail_on_error: false)

            run_command("longleaf deregister -c #{config_path} -l @-", fail_on_error: false)
            pipe_in_file(from_list_file)
            close_input
          end
          
          it 'deregisters both files' do
            expect(last_command_started).to have_output(/SUCCESS deregister #{file_path}/)
            expect(file_deregistered?(file_path, md_dir)).to be true
            expect(last_command_started).to have_output(/SUCCESS deregister #{file_path2}/)
            expect(file_deregistered?(file_path2, md_dir)).to be true
            expect(last_command_started).to have_exit_status(0)
          end
        end
        
        context 'deregister multiple files from file list invalid format' do
          let!(:from_list_file) { create_test_file(dir: path_dir, name: "file_list.txt", content:
                       "#{file_path} #{file_path2}") }
          
          before do
            run_command_and_stop("longleaf register -c #{config_path} -f #{file_path2}", fail_on_error: false)

            run_command_and_stop("longleaf deregister -c #{config_path} -l '#{from_list_file}'", fail_on_error: false)
          end
          
          it 'fails to deregister' do
            expect(last_command_started).to have_output(
                /FAILURE deregister: File #{file_path} #{file_path2} does not exist./)
            expect(file_deregistered?(file_path, md_dir)).to be false
            expect(file_deregistered?(file_path2, md_dir)).to be false
          end
        end
        
        context 'deregister file from file list with trailing newline' do
          let!(:from_list_file) { create_test_file(dir: path_dir, name: "file_list.txt", content:
                       "#{file_path}\n") }
          
          before do
            run_command_and_stop("longleaf deregister -c #{config_path} -l '#{from_list_file}'", fail_on_error: false)
          end
          
          it 'deregisters file' do
            expect(last_command_started).to have_output(/SUCCESS deregister #{file_path}/)
            expect(file_deregistered?(file_path, md_dir)).to be true
            expect(last_command_started).to have_exit_status(0)
          end
        end
        
        context 'deregister with empty list file' do
          let!(:from_list_file) { create_test_file(dir: path_dir, name: "file_list.txt", content:
                       "") }
          
          before do
            run_command_and_stop("longleaf deregister -c #{config_path} -l '#{from_list_file}'", fail_on_error: false)
          end
          
          it 'deregisters both files' do
            expect(last_command_started).to have_output(/File list is empty, must provide one or more files for this operation/)
            expect(file_deregistered?(file_path, md_dir)).to be false
            expect(last_command_started).to have_exit_status(1)
          end
        end
      end
    end
  end

  def file_deregistered?(file_path, md_dir)
    metadata_path = File.join(md_dir, File.basename(file_path) + Longleaf::MetadataSerializer::metadata_suffix)
    return false unless File.exist?(metadata_path)
    Longleaf::MetadataDeserializer.deserialize(file_path: metadata_path).deregistered?
  end
end
