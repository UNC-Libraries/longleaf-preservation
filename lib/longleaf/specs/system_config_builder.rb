require 'longleaf/models/system_config_fields'
require 'yaml'

module Longleaf
  # Test helper for constructing system configuration hashes
  class SystemConfigBuilder
    SCF ||= Longleaf::SystemConfigFields

    attr_accessor :config

    def initialize
      @config = Hash.new
    end

    def with_index(adapter, connection)
      @config[SCF::MD_INDEX] = Hash.new
      @config[SCF::MD_INDEX][SCF::MD_INDEX_ADAPTER] = adapter
      @config[SCF::MD_INDEX][SCF::MD_INDEX_CONNECTION] = connection
      self
    end

    # @return the constructed configuration
    def get
      @config
    end
  end
end
