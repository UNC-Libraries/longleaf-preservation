require 'spec_helper'
require 'longleaf/helpers/selection_options_parser'
require 'longleaf/services/application_config_manager'
require 'tempfile'

describe Longleaf::SelectionOptionsParser do
  SelectionOptionsParser ||= Longleaf::SelectionOptionsParser
  FileSelector ||= Longleaf::FileSelector
  RegisteredFileSelector ||= Longleaf::RegisteredFileSelector
  ManifestDigestProvider ||= Longleaf::ManifestDigestProvider
  SingleDigestProvider ||= Longleaf::SingleDigestProvider
  PhysicalPathProvider ||= Longleaf::PhysicalPathProvider

  let(:app_config_manager) { build(:application_config_manager) }

  describe '.parse_registration_selection_options' do
    context 'with manifest option' do
      let(:manifest_file) { Tempfile.new(['manifest', '.txt']) }
      
      after do
        manifest_file.close
        manifest_file.unlink
      end

      context 'single algorithm manifest' do
        before do
          manifest_file.write("md5:\n")
          manifest_file.write("abc123  /path/to/file1.txt\n")
          manifest_file.write("def456  /path/to/file2.txt\n")
          manifest_file.rewind
        end

        it 'returns selector and digest provider with correct file paths' do
          options = { manifest: [manifest_file.path] }
          
          expect(FileSelector).to receive(:new).with(
            hash_including(
              file_paths: ['/path/to/file1.txt', '/path/to/file2.txt']
            )
          ).and_call_original
          
          selector, digest_provider, physical_provider = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
          
          expect(selector).to be_a(FileSelector)
          expect(digest_provider).to be_a(ManifestDigestProvider)
          expect(physical_provider).to be_a(PhysicalPathProvider)
        end

        it 'correctly parses digest mappings' do
          options = { manifest: [manifest_file.path] }
          selector, digest_provider, _ = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
          
          expect(digest_provider.get_digests('/path/to/file1.txt')).to eq({ 'md5' => 'abc123' })
          expect(digest_provider.get_digests('/path/to/file2.txt')).to eq({ 'md5' => 'def456' })
        end
      end

      context 'manifest with algorithm prefix' do
        before do
          manifest_file.write("abc123  /path/to/file1.txt\n")
          manifest_file.rewind
        end

        it 'uses algorithm from option prefix' do
          options = { manifest: ['sha256:' + manifest_file.path] }
          _, digest_provider, _ = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
          
          expect(digest_provider.get_digests('/path/to/file1.txt')).to eq({ 'sha256' => 'abc123' })
        end
      end

      context 'manifest with physical paths' do
        before do
          manifest_file.write("md5:\n")
          manifest_file.write("abc123  /logical/path.txt  /physical/path.txt\n")
          manifest_file.rewind
        end

        it 'correctly maps physical paths' do
          options = { manifest: [manifest_file.path] }
          _, _, physical_provider = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
          
          expect(physical_provider.get_physical_path('/logical/path.txt')).to eq('/physical/path.txt')
        end
      end

      context 'multiple manifests' do
        let(:manifest_file2) { Tempfile.new(['manifest2', '.txt']) }
        
        after do
          manifest_file2.close
          manifest_file2.unlink
        end

        before do
          manifest_file.write("abc123  /path/to/file1.txt\n")
          manifest_file.rewind
          
          manifest_file2.write("xyz789  /path/to/file1.txt\n")
          manifest_file2.rewind
        end

        it 'combines digests from multiple manifests' do
          options = { manifest: ['md5:' + manifest_file.path, 'sha1:' + manifest_file2.path] }
          _, digest_provider, _ = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
          
          digests = digest_provider.get_digests('/path/to/file1.txt')
          expect(digests).to eq({ 'md5' => 'abc123', 'sha1' => 'xyz789' })
        end
      end

      context 'manifest with quoted paths' do
        before do
          manifest_file.write("md5:\n")
          manifest_file.write("abc123  \"/path/with spaces/file.txt\"\n")
          manifest_file.rewind
        end

        it 'handles quoted paths correctly' do
          options = { manifest: [manifest_file.path] }
          _, digest_provider, _ = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
          
          expect(digest_provider.get_digests('/path/with spaces/file.txt')).to eq({ 'md5' => 'abc123' })
        end
      end
    end

    context 'with file option' do
      it 'returns selector for single file' do
        options = { file: '/path/to/file.txt' }
        
        expect(FileSelector).to receive(:new).with(
          hash_including(
            file_paths: ['/path/to/file.txt']
          )
        ).and_call_original
        
        selector, digest_provider, physical_provider = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
        
        expect(selector).to be_a(FileSelector)
        expect(digest_provider).to be_nil
        expect(physical_provider).to be_a(PhysicalPathProvider)
      end

      it 'returns selector for multiple comma-separated files' do
        options = { file: '/path/to/file1.txt, /path/to/file2.txt' }
        
        expect(FileSelector).to receive(:new).with(
          hash_including(
            file_paths: ['/path/to/file1.txt', '/path/to/file2.txt']
          )
        ).and_call_original
        
        selector, _, _ = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
        
        expect(selector).to be_a(FileSelector)
      end

      context 'with checksums' do
        it 'creates digest provider with valid checksums' do
          options = { 
            file: '/path/to/file.txt',
            checksums: 'md5:abc123,sha1:def456'
          }
          _, digest_provider, _ = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
          
          expect(digest_provider).to be_a(SingleDigestProvider)
        end

        it 'exits on invalid checksum format' do
          options = { 
            file: '/path/to/file.txt',
            checksums: 'invalid_format'
          }
          
          expect { SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager) }.to raise_error(SystemExit)
        end

        it 'exits on checksum with missing value' do
          options = { 
            file: '/path/to/file.txt',
            checksums: 'md5:'
          }
          
          expect { SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager) }.to raise_error(SystemExit)
        end
      end

      context 'with physical_path option' do
        it 'maps physical paths to logical paths' do
          options = { 
            file: '/logical1.txt, /logical2.txt',
            physical_path: '/physical1.txt, /physical2.txt'
          }
          
          expect(FileSelector).to receive(:new).with(
            hash_including(
              file_paths: ['/logical1.txt', '/logical2.txt']
            )
          ).and_call_original
          
          _, _, physical_provider = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
          
          expect(physical_provider.get_physical_path('/logical1.txt')).to eq('/physical1.txt')
          expect(physical_provider.get_physical_path('/logical2.txt')).to eq('/physical2.txt')
        end

        it 'exits when physical path count does not match file count' do
          options = { 
            file: '/logical1.txt, /logical2.txt',
            physical_path: '/physical1.txt'
          }
          
          expect { SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager) }.to raise_error(SystemExit)
        end
      end

      context 'with quoted file paths' do
        it 'handles quoted paths with spaces' do
          options = { file: '"/path/with spaces/file1.txt", /path/file2.txt' }
          
          expect(FileSelector).to receive(:new).with(
            hash_including(
              file_paths: ['/path/with spaces/file1.txt', '/path/file2.txt']
            )
          ).and_call_original
          
          selector, _, _ = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
          
          expect(selector).to be_a(FileSelector)
        end
      end
    end

    context 'with from_list option' do
      let(:list_file) { Tempfile.new(['filelist', '.txt']) }
      
      after do
        list_file.close
        list_file.unlink
      end

      before do
        list_file.write("/path/to/file1.txt\n")
        list_file.write("/path/to/file2.txt\n")
        list_file.write("/path/to/file3.txt\n")
        list_file.rewind
      end

      it 'returns selector from file list with correct file paths' do
        options = { from_list: list_file.path }
        
        expect(FileSelector).to receive(:new).with(
          hash_including(
            file_paths: ['/path/to/file1.txt', '/path/to/file2.txt', '/path/to/file3.txt']
          )
        ).and_call_original
        
        selector, digest_provider, physical_provider = SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager)
        
        expect(selector).to be_a(FileSelector)
        expect(digest_provider).to be_nil
        expect(physical_provider).to be_a(PhysicalPathProvider)
      end
    end

    context 'validation of mutually exclusive options' do
      it 'exits when both manifest and file are provided' do
        manifest_file = Tempfile.new(['manifest', '.txt'])
        manifest_file.write("md5:\nabc123  /file.txt\n")
        manifest_file.rewind
        
        options = { 
          manifest: [manifest_file.path],
          file: '/path/to/file.txt'
        }
        
        expect { SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager) }.to raise_error(SystemExit)
        
        manifest_file.close
        manifest_file.unlink
      end

      it 'exits when both file and from_list are provided' do
        list_file = Tempfile.new(['list', '.txt'])
        list_file.write("/file.txt\n")
        list_file.rewind
        
        options = { 
          file: '/path/to/file.txt',
          from_list: list_file.path
        }
        
        expect { SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager) }.to raise_error(SystemExit)
        
        list_file.close
        list_file.unlink
      end

      it 'exits when both manifest and from_list are provided' do
        manifest_file = Tempfile.new(['manifest', '.txt'])
        manifest_file.write("md5:\nabc123  /file.txt\n")
        manifest_file.rewind
        
        list_file = Tempfile.new(['list', '.txt'])
        list_file.write("/file.txt\n")
        list_file.rewind
        
        options = { 
          manifest: [manifest_file.path],
          from_list: list_file.path
        }
        
        expect { SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager) }.to raise_error(SystemExit)
        
        manifest_file.close
        manifest_file.unlink
        list_file.close
        list_file.unlink
      end

      it 'exits when no selection options are provided' do
        options = {}
        
        expect { SelectionOptionsParser.parse_registration_selection_options(options, app_config_manager) }.to raise_error(SystemExit)
      end
    end
  end

  describe '.parse_manifest' do
    context 'with invalid manifest entries' do
      let(:manifest_file) { Tempfile.new(['manifest', '.txt']) }
      
      after do
        manifest_file.close
        manifest_file.unlink
      end

      it 'exits on invalid entry with too few parts' do
        manifest_file.write("md5:\nabc123\n")
        manifest_file.rewind
        
        expect { SelectionOptionsParser.parse_manifest([manifest_file.path]) }.to raise_error(SystemExit)
      end

      it 'exits on unknown digest algorithm' do
        manifest_file.write("unknownalg:\nabc123  /file.txt\n")
        manifest_file.rewind
        
        expect { SelectionOptionsParser.parse_manifest([manifest_file.path]) }.to raise_error(SystemExit)
      end

      it 'exits when manifest has no algorithm specified' do
        manifest_file.write("abc123  /file.txt\n")
        manifest_file.rewind
        
        expect { SelectionOptionsParser.parse_manifest([manifest_file.path]) }.to raise_error(SystemExit)
      end
    end

    context 'reading from STDIN' do
      it 'exits when multiple STDIN manifests are specified' do
        expect { SelectionOptionsParser.parse_manifest(['@-', 'md5:@-']) }.to raise_error(SystemExit)
      end
    end
  end

  describe '.split_quoted' do
    it 'splits unquoted strings by spaces' do
      result = SelectionOptionsParser.split_quoted('word1 word2 word3')
      expect(result).to eq(['word1', 'word2', 'word3'])
    end

    it 'preserves quoted strings with spaces' do
      result = SelectionOptionsParser.split_quoted('"word1 word2" word3')
      expect(result).to eq(['word1 word2', 'word3'])
    end

    it 'handles single quotes' do
      result = SelectionOptionsParser.split_quoted("'word1 word2' word3")
      expect(result).to eq(['word1 word2', 'word3'])
    end

    it 'handles custom delimiter' do
      result = SelectionOptionsParser.split_quoted('word1, word2, word3', "\\s*,\\s*")
      expect(result).to eq(['word1', 'word2', 'word3'])
    end

    it 'handles limit parameter' do
      result = SelectionOptionsParser.split_quoted('word1 word2 word3', "\\s+", 2)
      expect(result).to eq(['word1', 'word2 word3'])
    end

    it 'filters out empty strings' do
      result = SelectionOptionsParser.split_quoted('word1  word2')
      expect(result).to eq(['word1', 'word2'])
    end
  end

  describe '.create_registered_selector' do
    context 'with file option' do
      it 'returns registered file selector with correct file paths' do
        options = { file: '/path/to/file1.txt, /path/to/file2.txt' }
        
        expect(RegisteredFileSelector).to receive(:new).with(
          hash_including(
            file_paths: ['/path/to/file1.txt', '/path/to/file2.txt']
          )
        ).and_call_original
        
        selector = SelectionOptionsParser.create_registered_selector(options, app_config_manager)
        
        expect(selector).to be_a(RegisteredFileSelector)
      end
    end

    context 'with from_list option' do
      let(:list_file) { Tempfile.new(['list', '.txt']) }
      
      after do
        list_file.close
        list_file.unlink
      end

      before do
        list_file.write("/path/to/file1.txt\n")
        list_file.write("/path/to/file2.txt\n")
        list_file.rewind
      end

      it 'returns registered file selector from list with correct file paths' do
        options = { from_list: list_file.path }
        
        expect(RegisteredFileSelector).to receive(:new).with(
          hash_including(
            file_paths: ['/path/to/file1.txt', '/path/to/file2.txt']
          )
        ).and_call_original
        
        selector = SelectionOptionsParser.create_registered_selector(options, app_config_manager)
        
        expect(selector).to be_a(RegisteredFileSelector)
      end
    end

    context 'validation of mutually exclusive options' do
      it 'exits when both file and location are provided' do
        options = { 
          file: '/path/to/file.txt',
          location: 'location1'
        }
        
        expect { SelectionOptionsParser.create_registered_selector(options, app_config_manager) }.to raise_error(SystemExit)
      end

      it 'exits when no selection options are provided' do
        options = {}
        
        expect { SelectionOptionsParser.create_registered_selector(options, app_config_manager) }.to raise_error(SystemExit)
      end
    end
  end

  describe '.read_from_list' do
    let(:list_file) { Tempfile.new(['list', '.txt']) }
    
    after do
      list_file.close
      list_file.unlink
    end

    before do
      list_file.write("/path/to/file1.txt\n")
      list_file.write("/path/to/file2.txt\n")
      list_file.write("/path/to/file3.txt\n")
      list_file.rewind
    end

    it 'reads files from list file' do
      result = SelectionOptionsParser.read_from_list(list_file.path)
      
      expect(result).to eq(['/path/to/file1.txt', '/path/to/file2.txt', '/path/to/file3.txt'])
    end

    it 'strips whitespace from lines' do
      list_file2 = Tempfile.new(['list2', '.txt'])
      list_file2.write("  /path/to/file1.txt  \n")
      list_file2.write("/path/to/file2.txt\n")
      list_file2.rewind
      
      result = SelectionOptionsParser.read_from_list(list_file2.path)
      
      expect(result).to eq(['/path/to/file1.txt', '/path/to/file2.txt'])
      
      list_file2.close
      list_file2.unlink
    end

    it 'exits when file does not exist' do
      expect { SelectionOptionsParser.read_from_list('/nonexistent/file.txt') }.to raise_error(SystemExit)
    end

    it 'exits when list is empty' do
      empty_file = Tempfile.new(['empty', '.txt'])
      empty_file.rewind
      
      expect { SelectionOptionsParser.read_from_list(empty_file.path) }.to raise_error(SystemExit)
      
      empty_file.close
      empty_file.unlink
    end

    it 'exits when from_list parameter is empty string' do
      expect { SelectionOptionsParser.read_from_list('  ') }.to raise_error(SystemExit)
    end
  end
end
