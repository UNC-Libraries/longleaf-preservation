module Longleaf
  # Provides a single set of digests for files
  class SingleDigestProvider
    def initialize(digests)
      @digests = digests
    end

    def get_digests(file_path)
      return nil if @digests.nil?
      @digests
    end
  end
end
