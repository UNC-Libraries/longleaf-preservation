require 'longleaf/models/md_fields'
require 'longleaf/helpers/service_date_helper'
require 'yaml'

module Longleaf
  # Test helper for constructing file metadata records
  class MetadataBuilder
    MF ||= Longleaf::MDFields
  
    def initialize(file_path: nil, registered: ServiceDateHelper::formatted_timestamp)
      @data = Hash.new
      @services = Hash.new
      
      unless file_path.nil?
        @last_modified = File.mtime(file_path).utc.iso8601(3)
        @file_size = File.size(file_path)
      end
      
      @registered = registered
    end
    
    def deregistered(timestamp = ServiceDateHelper::formatted_timestamp)
      @deregistered = timestamp
      self
    end
    
    def with_checksum(alg, value)
      @checksums = Hash.new unless @data.key?(MF::CHECKSUMS)
      @checksums[alg] = value
      self
    end
    
    def with_service(name, timestamp: ServiceDateHelper::formatted_timestamp, run_needed: false, properties: nil,
          failure_timestamp: nil)
      timestamp = format_timestamp(timestamp)
      failure_timestamp = format_timestamp(failure_timestamp) unless failure_timestamp.nil?
      
      @services[name] = ServiceRecord.new(
          properties: properties.nil? ? Hash.new : nil,
          timestamp: timestamp,
          run_needed: run_needed)
      @services[name].failure_timestamp = failure_timestamp
      self
    end
    
    def with_properties(properties)
      @properties = properties
    end
    
    # @return the constructed metadata record
    def get_metadata_record
      MetadataRecord.new(properties: @properties,
          services: @services,
          deregistered: @deregistered,
          registered: @registered,
          checksums: @checksums,
          file_size: @file_size,
          last_modified: @last_modified)
    end
    
    # Add the generated metadata record to the given file record
    def register_to(file_rec)
      file_rec.metadata_record = get_metadata_record
      self
    end
    
    # Writes the metadata record from this builder into a temporary file, or if a file
    # record is provided, then to the expected metadata path for the record, and assigns
    # the result as the metadata record for the file record.
    # @return the file path of the config file
    def write_to_yaml_file(file_rec: nil)
      md_path = nil
      if file_rec.nil?
        md_path = TempFile.new(['metadata', 'yml']).path
      else
        md_path = file_rec.metadata_path
      end
      
      md_rec = get_metadata_record
      MetadataSerializer::write(metadata: md_rec, file_path: md_path)
      file_rec.metadata_record = md_rec
      
      md_path
    end
    
    private
    def format_timestamp(timestamp)
      timestamp.kind_of?(Time) ? ServiceDateHelper::formatted_timestamp(timestamp) : timestamp
    end
  end
end