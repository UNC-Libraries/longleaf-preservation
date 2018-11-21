require 'spec_helper'
require 'longleaf/errors'
require 'longleaf/preservation_services/fixity_check_service'
require 'longleaf/models/service_fields'
require 'longleaf/specs/file_helpers'
require 'digest'
require 'fileutils'

describe Longleaf::FixityCheckService do
  include Longleaf::FileHelpers
  
  FixityCheckService ||= Longleaf::FixityCheckService
  VERIFY_EVENT ||= Longleaf::EventNames::VERIFY
  ChecksumMismatchError ||= Longleaf::ChecksumMismatchError
  
  describe '.initialize' do
    context 'no algorithms configured' do
      let(:service_def) { build(:service_definition) }
      
      it { expect { FixityCheckService.new(service_def) }.to raise_error(ArgumentError,
          /requires a list of one or more digest algorithms/) }
    end
    
    context 'empty algorithms configured' do
      let(:service_def) { make_service_def([]) }
      
      it { expect { FixityCheckService.new(service_def) }.to raise_error(ArgumentError,
          /requires a list of one or more digest algorithms/) }
    end
    
    context 'valid algorithms configured' do
      let(:service_def) { make_service_def(['sha1', 'md5']) }
      
      it { expect(FixityCheckService.new(service_def)).to be_a(FixityCheckService) }
    end
    
    context 'valid algorithms with varied formatting configured' do
      let(:service_def) { make_service_def(['sha-1', 'MD5']) }
      
      it { expect(FixityCheckService.new(service_def)).to be_a(FixityCheckService) }
    end
    
    context 'invalid algorithms configured' do
      let(:service_def) { make_service_def(['md5', 'indigestion']) }
      
      it { expect { FixityCheckService.new(service_def) }.to raise_error(ArgumentError,
          /Unsupported checksum algorithm 'indigestion'/) }
    end
    
    context 'invalid digest_absent configured' do
      let(:service_def) { make_service_def(['sha1'], absent_digest: 'who cares') }
      
      it { expect { FixityCheckService.new(service_def) }.to raise_error(ArgumentError,
          /Invalid option 'who cares' for property absent_digest/) }
    end
  end
  
  describe '.is_applicable?' do
    context 'with valid algorithms' do
      let(:service_def) { make_service_def(['sha1', 'md5']) }
      let(:fixity_service) { FixityCheckService.new(service_def) }
      
      it "returns true for verify event" do
        expect(fixity_service.is_applicable?(VERIFY_EVENT)).to be true
      end
      
      it "returns false for non-verify event" do
        expect(fixity_service.is_applicable?(Longleaf::EventNames::REGISTER)).to be false
      end
      
      it "returns false for invalid event" do
        expect(fixity_service.is_applicable?('nope')).to be false
      end
    end
  end
  
  describe '.perform' do
    MD5_DIGEST ||= 'f11c72a98bf0b6e31f0b0af786a43ba7'
    SHA1_DIGEST ||= '00337cfb20489c72b736b268fdba32c027bdd62b'
    SHA2_DIGEST ||= '820eb62b7660a216f711bd0df37ac8a176b662a159959870edc200b857262daf'
    SHA384_DIGEST ||= '445fa0589ef76020078d8bef714a8fb8165078700eea84be16625a614fed4bb7f1d5a38e0e94524f7c6f64ed58a4aa35'
    SHA512_DIGEST ||= '31b8effa4df268c6bc579e4374b4336d45ef178178ac093c0081754aa0b8d84153b5c67bfb3a88546d9ec91ba7d29f676fbb9cd8a2f8ed2a9027470a89e41a55'
    RMD160_DIGEST ||= 'b2da06af200a1c4c9f35ff3422c68391ad01550d'
    
    let(:file_path) { create_test_file(content: 'checksum me') }
    after do
      FileUtils.rm_f(file_path)
    end
    
    context 'with default absent_digest behavior' do
      let(:service_def) { make_service_def(['sha1']) }
      let(:fixity_service) { FixityCheckService.new(service_def) }
      
      context 'file with missing checksum' do
        let(:md_rec) { build(:metadata_record, checksums: {} ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to raise_error(ChecksumMismatchError,
            /no existing digest of type 'sha1'/) }
      end
    end
    
    context 'with absent_digest behavior set to fail' do
      let(:service_def) { make_service_def(['sha1'], absent_digest: FixityCheckService::FAIL_IF_ABSENT) }
      let(:fixity_service) { FixityCheckService.new(service_def) }
      
      context 'file with matching checksum' do
        let(:md_rec) { build(:metadata_record, checksums: { 'sha1' => SHA1_DIGEST } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to_not raise_error }
      end
      
      context 'file with missing checksum' do
        let(:md_rec) { build(:metadata_record, checksums: {} ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to raise_error(ChecksumMismatchError,
            /no existing digest of type 'sha1'/) }
      end
      
      context 'file with incorrect checksum' do
        let(:md_rec) { build(:metadata_record, checksums: { 'sha1' => 'not_right' } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to raise_error(ChecksumMismatchError) }
      end
      
      context 'file has no checksums' do
        let(:md_rec) { build(:metadata_record) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to raise_error(ChecksumMismatchError,
            /no existing digest of type 'sha1'/) }
      end
    end
    
    context 'with absent_digest behavior set to generate' do
      let(:service_def) { make_service_def(['sha1'], absent_digest: FixityCheckService::GENERATE_IF_ABSENT) }
      let(:fixity_service) { FixityCheckService.new(service_def) }
      
      context 'file with matching checksum' do
        let(:md_rec) { build(:metadata_record, checksums: { 'sha1' => SHA1_DIGEST } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to_not raise_error }
      end
      
      context 'file with missing checksum' do
        let(:md_rec) { build(:metadata_record, checksums: {} ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it "metadata updated with missing checksum" do
          expect(md_rec.checksums.key?('sha1')).to be false
          expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to_not raise_error
          expect(md_rec.checksums['sha1']).to eq SHA1_DIGEST
        end
      end
      
      context 'file has no checksums' do
        let(:md_rec) { build(:metadata_record) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it "metadata updated with missing checksum" do
          expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to_not raise_error
          expect(md_rec.checksums['sha1']).to eq SHA1_DIGEST
        end
      end
    end
    
    context 'with absent_digest behavior set to ignore' do
      let(:service_def) { make_service_def(['sha1'], absent_digest: FixityCheckService::IGNORE_IF_ABSENT) }
      let(:fixity_service) { FixityCheckService.new(service_def) }
      
      context 'file with matching checksum' do
        let(:md_rec) { build(:metadata_record, checksums: { 'sha1' => SHA1_DIGEST } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to_not raise_error }
      end
      
      context 'file with missing checksum' do
        let(:md_rec) { build(:metadata_record, checksums: {} ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to_not raise_error }
      end
      
      context 'file with incorrect checksum' do
        let(:md_rec) { build(:metadata_record, checksums: { 'sha1' => 'not_right' } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to raise_error(ChecksumMismatchError) }
      end
      
      context 'file has no checksums' do
        let(:md_rec) { build(:metadata_record) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to_not raise_error }
      end
    end
    
    context 'with multiple configured checksums' do
      let(:service_def) { make_service_def(['sha1', 'md5']) }
      let(:fixity_service) { FixityCheckService.new(service_def) }
      
      context 'file with multiple matching checksum' do
        let(:md_rec) { build(:metadata_record, checksums: { 'sha1' => SHA1_DIGEST, 'md5' => MD5_DIGEST } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to_not raise_error }
      end
      
      context 'file with one checksum mistmatch' do
        let(:md_rec) { build(:metadata_record, checksums: { 'sha1' => SHA1_DIGEST, 'md5' => 'not_right' } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to raise_error(ChecksumMismatchError) }
      end
      
      context 'file contains unconfigured checksum' do
        let(:md_rec) { build(:metadata_record, checksums: {
            'sha1' => SHA1_DIGEST,
            'md5' => MD5_DIGEST,
            'indigestion' => 'nope' } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
        
        it "passes, with no changes to stored checksums" do
          expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to_not raise_error
          expect(md_rec.checksums['indigestion']).to eq 'nope'
        end
      end
      
      context 'file does not exist' do
        let(:md_rec) { build(:metadata_record, checksums: { 'sha1' => SHA1_DIGEST} ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }

        before do
          File.delete(file_path)
        end
        
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to raise_error(Errno::ENOENT) }
      end
        
    end
      
    context 'with all checksums configured' do
      let(:service_def) { make_service_def(['sha1', 'md5', 'sha2', 'sha384', 'sha512', 'rmd160'],
          absent_digest: FixityCheckService::IGNORE_IF_ABSENT) }
      let(:fixity_service) { FixityCheckService.new(service_def) }
    
      context 'file with all matching checksums' do
        let(:md_rec) { build(:metadata_record, checksums: {
          'sha1' => SHA1_DIGEST,
          'md5' => MD5_DIGEST,
          'sha2' => SHA2_DIGEST,
          'sha384' => SHA384_DIGEST,
          'sha512' => SHA512_DIGEST,
          'rmd160' => RMD160_DIGEST
        } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
      
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to_not raise_error }
      end
      
      context 'file with all sha2 mismatch' do
        let(:md_rec) { build(:metadata_record, checksums: { 'sha2' => 'sha2_not_right' } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
      
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to raise_error(ChecksumMismatchError,
            /expected 'sha2_not_right'/) }
      end
      
      context 'file with all sha384 mismatch' do
        let(:md_rec) { build(:metadata_record, checksums: { 'sha384' => 'sha384_not_right' } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
      
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to raise_error(ChecksumMismatchError,
            /expected 'sha384_not_right'/) }
      end
      
      context 'file with all sha512 mismatch' do
        let(:md_rec) { build(:metadata_record, checksums: { 'sha512' => 'sha512_not_right' } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
      
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to raise_error(ChecksumMismatchError,
            /expected 'sha512_not_right'/) }
      end
      
      context 'file with all rmd160 mismatch' do
        let(:md_rec) { build(:metadata_record, checksums: { 'rmd160' => 'rmd160_not_right' } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
      
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to raise_error(ChecksumMismatchError,
            /expected 'rmd160_not_right'/) }
      end
      
      context 'file with matching sha2 with irregular formatting' do
        let(:md_rec) { build(:metadata_record, checksums: { 'SHA-2' => SHA2_DIGEST } ) }
        let(:file_rec) { make_file_record(file_path, md_rec) }
      
        it { expect { fixity_service.perform(file_rec, VERIFY_EVENT) }.to_not raise_error }
      end
    end
  end
  
  private
  def make_service_def(digest_algs, absent_digest: nil)
    properties = Hash.new
    properties[Longleaf::ServiceFields::DIGEST_ALGORITHMS] = digest_algs unless digest_algs.nil?
    properties[Longleaf::FixityCheckService::ABSENT_DIGEST_PROPERTY] = absent_digest unless absent_digest.nil?
    build(:service_definition, properties: properties)
  end
  
  def make_file_record(file_path, md_rec)
    storage_loc = build(:storage_location)
    file_rec = build(:file_record, file_path: file_path, storage_location: storage_loc)
    file_rec.metadata_record = md_rec
    file_rec
  end
end