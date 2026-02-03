require 'find'

module Longleaf
  # Helper for common operations with OCFL objects
  class OcflHelper
    # Calculate aggregated statistics about files in the provided directory
    def self.summarized_file_info(physical_path)
      total_size = 0
      file_count = 0
      latest_mtime = nil

      Find.find(physical_path) do |path|
        next unless File.file?(path)

        stat = File.stat(path)
        file_count += 1
        total_size += stat.size

        mtime = stat.mtime
        latest_mtime = mtime if latest_mtime.nil? || mtime > latest_mtime
      end
      return total_size, file_count, latest_mtime
    end
  end
end