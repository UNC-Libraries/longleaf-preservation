require 'pathname'
require 'longleaf/models/md_fields'
require 'longleaf/errors'
require_relative 'configuration_validator'

module Longleaf
  # Validator for file metadata
  class MetadataValidator < ConfigurationValidator
    MDF ||= MDFields

    # @param config [Hash] hash containing the application configuration
    def initialize(config)
      super(config)
    end

    protected
    # Validates the provided metadata for a file to ensure that it is syntactically correct and field types
    # are validate.
    def validate
      assert("Metadata must be a hash, but a #{@config.class} was provided", @config.class == Hash)
      assert("Metadata must contain a '#{MDF::DATA}' key", @config.key?(MDF::DATA))
      assert("Metadata must contain a '#{MDF::SERVICES}' key", @config.key?(MDF::SERVICES))

      data = @config[MDF::DATA]
      register_on_failure { validate_date_field(data, MDF::REGISTERED_TIMESTAMP) }
      register_on_failure { validate_date_field(data, MDF::DEREGISTERED_TIMESTAMP, required: false) }
      register_on_failure { validate_date_field(data, MDF::LAST_MODIFIED) }
      register_on_failure { validate_object_type(data) }

      register_on_failure { validate_positive_integer(data, MDF::FILE_SIZE) }
      # File count is required for ocfl objects only
      file_count_required = data[MDF::OBJECT_TYPE] == MDF::OCFL_TYPE
      register_on_failure { validate_positive_integer(data, MDF::FILE_COUNT, required: file_count_required) }

      checksums = data[MDF::CHECKSUMS]
      register_on_failure do
        if !checksums.nil? && !checksums.is_a?(Hash)
          fail("Field '#{MDF::CHECKSUMS}' must be a map of algorithms to digests, but was a #{checksums.class}")
        end
      end

      # Ensure that any service timestamps present are valid dates
      services = @config[MDF::SERVICES]
      services.each do |service_name, service_rec|
        register_on_failure { validate_date_field(service_rec, MDF::SERVICE_TIMESTAMP, required: false) }
      end
    end

    def validate_date_field(section, field_key, required: true)
      field_val = section[field_key]

      if field_val
        begin
          Time.iso8601(section[field_key])
        rescue ArgumentError
          fail("Field '#{field_key}' must be a valid ISO8601 timestamp, but contained value '#{section[field_key]}'")
        end
      elsif required
        fail("Metadata must contain a '#{field_key}' field")
      end
    end

    def validate_positive_integer(section, field_key, required: true)
      field_val = section[field_key]

      if field_val
        begin
          val = field_val.is_a?(Integer) ? field_val : Integer(field_val, 10)
          if val < 0
            fail("Field '#{field_key}' must be a positive integer")
          end
        rescue ArgumentError => err
          fail("Field '#{field_key}' must be a positive integer")
        end
      elsif required
        fail("Metadata must contain a '#{field_key}' field")
      end
    end

    def validate_object_type(section)
      field_val = section[MDF::OBJECT_TYPE]

      if field_val && field_val != MDF::OCFL_TYPE
        fail("Field '#{MDF::OBJECT_TYPE}' must be nil or '#{MDF::OCFL_TYPE}', but value was '#{field_val}'")
      end
    end
  end
end
