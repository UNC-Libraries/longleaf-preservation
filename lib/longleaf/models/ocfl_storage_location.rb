unless RUBY_ENGINE == 'jruby'
  raise LoadError, "OcflStorageLocation requires JRuby"
end

require 'longleaf/models/filesystem_storage_location'
require 'longleaf/models/storage_types'
require 'longleaf/errors'
require 'lock_jar'

java_import 'io.ocfl.api.DigestAlgorithmRegistry'
java_import 'io.ocfl.core.OcflRepositoryBuilder'
java_import 'io.ocfl.core.storage.OcflStorageBuilder'
java_import 'io.ocfl.core.extension.storage.layout.config.HashedNTupleLayoutConfig'
java_import 'io.ocfl.core.path.mapper.LogicalPathMappers'
java_import 'java.nio.file.Paths'

module Longleaf
  # A storage location backed by an OCFL repository on a local filesystem.
  # Requires JRuby; uses ocfl-java to open and interact with the OCFL repository.
  #
  # Configuration properties (in addition to the base StorageLocation 'path'):
  #   * 'digest_algorithm' - OCFL inventory digest algorithm (default: 'sha512').
  #                          Must be an algorithm name recognised by DigestAlgorithmRegistry,
  #                          e.g. 'md5', 'sha1', 'sha256', 'sha512'.
  #   * 'verify_inventory'  - Whether to verify the inventory digest on read (default: true).
  class OcflStorageLocation < FilesystemStorageLocation
    OCFL_STORAGE_TYPE = 'ocfl'

    DIGEST_ALGORITHM_PROPERTY = 'digest_algorithm'
    VERIFY_INVENTORY_PROPERTY = 'verify_inventory'

    DEFAULT_DIGEST_ALGORITHM = 'sha512'

    def initialize(name, config, md_loc)
      super
      @digest_alg_name = (config[DIGEST_ALGORITHM_PROPERTY] || DEFAULT_DIGEST_ALGORITHM).downcase
      @verify_inventory = config.key?(VERIFY_INVENTORY_PROPERTY) ? config[VERIFY_INVENTORY_PROPERTY] : true
    end

    # @return the storage type for this location
    def type
      OCFL_STORAGE_TYPE
    end

    # Returns a lazily initialized read-only OcflRepository for this storage location.
    # The repository is opened with OcflRepositoryBuilder#build (non-mutable).
    #
    # @return [OcflRepository] the ocfl-java repository instance
    def ocfl_repository
      @ocfl_repository ||= build_repository
    end

    private

    def build_repository
      digest_alg = DigestAlgorithmRegistry.get_algorithm(@digest_alg_name)
      if digest_alg.nil?
        raise ArgumentError.new("Unsupported OCFL digest algorithm '#{@digest_alg_name}' " \
            "for storage location #{@name}")
      end

      storage = OcflStorageBuilder.builder
        .verify_inventory_digest(@verify_inventory)
        .file_system(Paths.get(@path))
        .build

      os_name = java.lang.System.get_property('os.name').to_s.downcase
      logical_path_mapper = if os_name.include?('windows')
        LogicalPathMappers.percent_encoding_windows_mapper
      else
        LogicalPathMappers.percent_encoding_linux_mapper
      end

      builder = OcflRepositoryBuilder.new
      builder.default_layout_config(HashedNTupleLayoutConfig.new)
      builder.logical_path_mapper(logical_path_mapper)
      builder.ocfl_config { |cfg| cfg.set_default_digest_algorithm(digest_alg) }
      builder.storage(storage)
      builder.build
    end
  end
end