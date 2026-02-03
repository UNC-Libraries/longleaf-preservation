require 'longleaf/events/register_event'
require 'longleaf/models/md_fields'
require 'longleaf/helpers/ocfl_helper'
require 'find'

module Longleaf
  # Event to register an OCFL file with longleaf
  class RegisterOcflEvent < RegisterEvent
    
    private
    def populate_object_type
      md_rec = @file_rec.metadata_record
      md_rec.object_type = MDFields::OCFL_TYPE
    end

    def populate_file_properties
      md_rec = @file_rec.metadata_record
      physical_path = @file_rec.physical_path

      # Calculate aggregate properties for OCFL object
      total_size, file_count, latest_mtime = OcflHelper.summarized_file_info(physical_path)

      md_rec.last_modified = latest_mtime.utc.iso8601(3) unless latest_mtime.nil?
      md_rec.file_size = total_size
      md_rec.file_count = file_count

      if physical_path != @file_rec.path
        md_rec.physical_path = physical_path
      else
        md_rec.physical_path = nil
      end
    end
  end
end
