require 'longleaf/events/register_event'
require 'longleaf/models/md_fields'
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
      total_size = 0
      file_count = 0
      latest_mtime = nil

      Find.find(physical_path) do |path|
        next unless File.file?(path)
        
        stat = File.stat(path)
        puts "Size of #{path} = #{stat.size}"
        file_count += 1
        total_size += stat.size
        
        mtime = stat.mtime
        latest_mtime = mtime if latest_mtime.nil? || mtime > latest_mtime
      end

      md_rec.last_modified = latest_mtime.utc.iso8601(3)
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
