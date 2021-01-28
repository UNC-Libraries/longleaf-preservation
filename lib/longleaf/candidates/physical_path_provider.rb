module Longleaf
  # Provides physical paths for logical paths from a mapping
  class PhysicalPathProvider
    # @param phys_mapping hash with logical paths as keys, physical paths as values
    def initialize(phys_mapping = Hash.new)
      @phys_mapping = phys_mapping
    end

    # @param logical_path [String] logical path of file
    # @return physical path of the file
    def get_physical_path(logical_path)
      # return the logical path itself if no physical path is mapped
      return logical_path unless @phys_mapping.key?(logical_path)
      @phys_mapping[logical_path]
    end
  end
end
