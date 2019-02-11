require 'digest'

module Longleaf
  # Helper methods for generating digests
  class DigestHelper
    
    # Get a Digest class for the specified algorithm
    # @param alg [String] name of the digest algorithm
    # @return [Digest] A digest class for the requested algorithm
    # @raise [InvalidDigestAlgorithmError] if an unknown digest algorithm is requested
    def self.start_digest(alg)
      case alg
      when 'md5'
        return Digest::MD5.new
      when 'sha1'
        return Digest::SHA1.new
      when 'sha2', 'sha256'
        return Digest::SHA2.new
      when 'sha384'
        return Digest::SHA2.new(384)
      when 'sha512'
        return Digest::SHA2.new(512)
      when 'rmd160'
        return Digest::RMD160.new
      else
        raise InvalidDigestAlgorithmError.new("Cannot produce digest for unknown algorithm '#{alg}'.")
      end
    end
  end
end