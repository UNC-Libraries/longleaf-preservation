require 'spec_helper'
require 'longleaf/services/metadata_validator'
require 'longleaf/services/metadata_serializer'
require 'longleaf/errors'
require 'longleaf/specs/config_validator_helpers'
require 'longleaf/helpers/service_date_helper'
require 'longleaf/models/md_fields'
require 'longleaf/specs/metadata_builder'
require 'longleaf/specs/file_helpers'
require 'fileutils'

describe Longleaf::MetadataValidator do
  include Longleaf::ConfigValidatorHelpers
  include Longleaf::FileHelpers
  MDF ||= Longleaf::MDFields
  MDBuilder ||= Longleaf::MetadataBuilder

  let(:test_file) { create_test_file }

  let(:validator) { build(:metadata_validator, config: md) }

  after do
    FileUtils.rm(test_file)
  end

  describe '#validate_config' do
    context 'with non-hash metadata' do
      let(:md) { 'bad' }

      it { fails_validation_with_error(validator, /must be a hash/) }
    end

    context 'with no data field' do
      let(:md) { { MDF::SERVICES => {} } }

      it { fails_validation_with_error(validator, /must contain a 'data'/) }
    end

    context 'with no services field' do
      let(:md) { { MDF::DATA => {} } }

      it { fails_validation_with_error(validator, /must contain a 'services'/) }
    end

    context 'missing registered timestamp' do
      let(:md) { md_hash(MDBuilder.new(file_path: test_file, registered: nil)) }

      it { fails_validation_with_error(validator, /must contain a 'registered' field/) }
    end

    context 'invalid registered timestamp' do
      let(:md) { md_hash(MDBuilder.new(file_path: test_file, registered: "don't worry about it")) }

      it { fails_validation_with_error(validator, /'registered' must be a valid ISO8601 timestamp/) }
    end

    context 'missing last modified timestamp' do
      let(:md) { md_hash(MDBuilder.new(file_path: test_file)) }
      before do
        md[MDF::DATA].delete(MDF::LAST_MODIFIED)
      end

      it { fails_validation_with_error(validator, /must contain a 'last-modified' field/) }
    end

    context 'missing last modified timestamp' do
      let(:md) { md_hash(MDBuilder.new(file_path: test_file)) }
      before do
        md[MDF::DATA][MDF::LAST_MODIFIED] = 'never'
      end

      it { fails_validation_with_error(validator, /'last-modified' must be a valid ISO8601 timestamp/) }
    end

    context 'invalid deregistered timestamp' do
      let(:md) {
        md_hash(MDBuilder.new(file_path: test_file)
            .deregistered("pretty much never"))
      }

      it { fails_validation_with_error(validator, /'deregistered' must be a valid ISO8601 timestamp/) }
    end

    context 'missing filesize' do
      let(:md) { md_hash(MDBuilder.new(file_path: test_file)) }
      before do
        md[MDF::DATA].delete(MDF::FILE_SIZE)
      end

      it { fails_validation_with_error(validator, /must contain a 'size' field/) }
    end

    context 'invalid filesize' do
      let(:md) { md_hash(MDBuilder.new(file_path: test_file)) }
      before do
        md[MDF::DATA][MDF::FILE_SIZE] = 'rather large'
      end

      it { fails_validation_with_error(validator, /'size' must be a positive integer/) }
    end

    context 'invalid value type for checksums' do
      let(:md) { md_hash(MDBuilder.new(file_path: test_file)) }
      before do
        md[MDF::DATA][MDF::CHECKSUMS] = 'checkme'
      end

      it { fails_validation_with_error(validator, /'checksums' must be a map of algorithms to digests/) }
    end

    context 'invalid service timestamp' do
      let(:md) {
        md_hash(MDBuilder.new(file_path: test_file)
            .with_service('service1', timestamp: 'nope'))
      }

      it { fails_validation_with_error(validator, /'timestamp' must be a valid ISO8601 timestamp/) }
    end

    context 'with multiple errors' do
      let(:md) {
        md_hash(MDBuilder.new(file_path: test_file, registered: nil)
          .deregistered("nope")
        )
      }
      before do
        md[MDF::DATA].delete(MDF::FILE_SIZE)
      end

      it 'returns all errors' do
        fails_validation_with_error(validator,
            /must contain a 'registered' field/,
            /'deregistered' must be a valid ISO8601 timestamp/,
            /must contain a 'size' field/)
      end
    end

    context 'with many valid fields' do
      let(:md) {
        md_hash(MDBuilder.new(file_path: test_file)
            .deregistered(Longleaf::ServiceDateHelper::formatted_timestamp)
            .with_checksum('sha1', 'digest')
            .with_service('service1'))
      }

      it { passes_validation(validator) }
    end
  end

  def md_hash(md_builder)
    md_rec = md_builder.get_metadata_record
    Longleaf::MetadataSerializer.to_hash(md_rec)
  end
end
