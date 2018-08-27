require 'yaml'
require_relative '../models/metadata_record'
require_relative '../models/md_fields'
require_relative '../models/metadata_error'

# Service which deserializes metadata files into MetadataRecord objects
module Longleaf
  class MetadataDeserializer
    MDF = Longleaf::MDFields
    
    # Deserialize a file into a MetadataRecord object
    #
    # @param file_path [String] path of the file to read. Required.
    # @param format [String] format the file is stored in. Default is 'yaml'.
    def self.deserialize(file_path:, format: 'yaml')
      case format
      when 'yaml'
        md = from_yaml(file_path)
      else
        raise ArgumentError.new('Invalid deserialization format #{format} specified')
      end
      
      if !md || !md.key?(MDF::DATA) || !md.key?(MDF::SERVICES)
        raise Longleaf::MetadataError.new("Invalid metadata file, did not contain data or services fields: #{file_path}")
      end
      
      MetadataRecord.new(md[MDF::DATA], md[MDF::SERVICES])
    end
    
    def self.from_yaml(file_path)
      YAML.load_file(file_path)
    end
  end
end