module Longleaf
  # Hash subclass which provides case insensitive keys, where keys are always downcased.
  class CaseInsensitiveHash < Hash
    def [](key)
      super _insensitive(key)
    end

    def []=(key, value)
      super _insensitive(key), value
    end

    def delete(key)
      super _insensitive(key)
    end

    def has_key?(key)
      super _insensitive(key)
    end

    def merge(other_hash)
      super other_hash.map {|k, v| [_insensitive(k), v] }.to_h
    end

    def merge!(other_hash)
      super other_hash.map {|k, v| [_insensitive(k), v] }.to_h
    end

    # Cause this hash to serialize as a regular hash to avoid deserialization failures
    def encode_with coder
      coder.represent_map nil, self
    end

    protected
    def _insensitive(key)
      key.respond_to?(:downcase) ? key.downcase : key
    end
  end
end
