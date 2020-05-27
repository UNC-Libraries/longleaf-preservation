require 'longleaf/errors'
require 'digest'

module Longleaf
  # Helper methods for generating digests
  class DigestHelper
    KNOWN_DIGESTS ||= ['md5', 'sha1', 'sha2', 'sha256', 'sha384', 'sha512', 'rmd160']

    # @param algs Either a string containing one or an array containing zero or more digest
    #    algorithm names.
    # @raise [InvalidDigestAlgorithmError] thrown if any of the digest algorithms listed are not
    #    known to the system.
    def self.validate_algorithms(algs)
      return if algs.nil?
      if algs.is_a?(String)
        unless self.is_known_algorithm?(algs)
          raise InvalidDigestAlgorithmError.new("Unknown digest algorithm #{algs}")
        end
      else
        unknown = algs.select { |alg| !KNOWN_DIGESTS.include?(alg) }
        unless unknown.empty?
          raise InvalidDigestAlgorithmError.new("Unknown digest algorithm(s): #{unknown}")
        end
      end
    end

    # @param [String] identifier of digest algorithm
    # @return [Boolean] true if the digest is a valid known algorithm
    def self.is_known_algorithm?(alg)
      KNOWN_DIGESTS.include?(algs)
    end

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
