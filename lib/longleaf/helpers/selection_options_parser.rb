require 'longleaf/candidates/file_selector'
require 'longleaf/candidates/registered_file_selector'
require 'longleaf/candidates/manifest_digest_provider'
require 'longleaf/candidates/single_digest_provider'

module Longleaf
  # Helper for parsing manifest inputs used for registration
  class SelectionOptionsParser
    extend Longleaf::Logging

    # Parses the provided options to construct a file selector and digest provider for
    # use in registration commands.
    # @param options [Hash] command options
    # @param app_config_manager [ApplicationConfigManager] app config manager
    # @return The file selector and digest provider.
    def self.parse_registration_selection_options(options, app_config_manager)
      there_can_be_only_one("Only one of the following selection options may be provided: -m, -f, -s",
          options, :file, :manifest, :location)

      if !options[:manifest].nil?
        digests_mapping = self.manifests_to_digest_mapping(options[:manifest])
        selector = FileSelector.new(file_paths: digests_mapping.keys, app_config: app_config_manager)
        digest_provider = ManifestDigestProvider.new(digests_mapping)
      elsif !options[:file].nil?
        if options[:checksums]
          checksums = options[:checksums]
          # validate checksum list format, must a comma delimited list of prefix:checksums
          if /^[^:,]+:[^:,]+(,[^:,]+:[^:,]+)*$/.match(checksums)
            # convert checksum list into hash with prefix as key
            checksums = Hash[*checksums.split(/\s*[:,]\s*/)]
            digest_provider = SingleDigestProvider.new(checksums)
          else
            logger.failure("Invalid checksums parameter format, see `longleaf help <command>` for more information")
            exit 1
          end
        end

        file_paths = options[:file].split(/\s*,\s*/)
        selector = FileSelector.new(file_paths: file_paths, app_config: app_config_manager)
      elsif !options[:location].nil?
        storage_locations = options[:location].split(/\s*,\s*/)
        selector = FileSelector.new(storage_locations: storage_locations, app_config: app_config_manager)
        digest_provider = SingleDigestProvider.new(nil)
      else
        logger.failure("Must provide one of the following file selection options: -f, l, or -m")
        exit 1
      end

      [selector, digest_provider]
    end

    def self.there_can_be_only_one(failure_msg, options, *names)
      got_one = false
      names.each do |name|
        if !options[name].nil?
          if got_one
            logger.failure(failure_msg)
            exit 1
          end
          got_one = true
        end
      end
    end

    # Parses the provided manifest options, reading the contents of the manifests to produce
    # a mapping from files to one or more algorithms.
    # @param manifest_vals [Array] List of manifest option values. They may be in one of the following formats:
    #       <alg_name>:<manifest_path> OR <alg_name>:@-
    #.      <manifest_path> OR @-
    # @return a hash containing the aggregated contents of the provided manifests. The keys are
    #    paths to manifested files. The values are hashes, mapping digest algorithms to digest values.
    def self.manifests_to_digest_mapping(manifest_vals)
      alg_manifest_pairs = []
      # interpret option inputs into a list of algorithms to manifest sources
      manifest_vals.each do |manifest_val|
        if manifest_val.include?(':')
          manifest_parts = manifest_val.split(':', 2)
          alg_manifest_pairs << manifest_parts
        else
          # algorithm not specified in option value
          alg_manifest_pairs << [nil, manifest_val]
        end
      end
      if alg_manifest_pairs.select { |mpair| mpair[1] == '@-' }.count > 1
        self.fail("Cannot specify more than one manifest from STDIN")
      end

      # read the provided manifests to build a mapping from file uri to all supplied digests
      digests_mapping = Hash.new { |h,k| h[k] = Hash.new }
      alg_manifest_pairs.each do |mpair|
        source_stream = nil
        # Determine if reading from a manifest file or stdin
        if mpair[1] == '@-'
          source_stream = $stdin
        else
          source_stream = File.new(mpair[1])
        end

        current_alg = mpair[0]
        multi_digest_manifest = current_alg.nil?
        source_stream.each_line do |line|
          line = line.strip
          if multi_digest_manifest && /^[a-zA-Z0-9]+:$/ =~ line
            # Found a digest algorithm header, assuming succeeding entries are of this type
            current_alg = line.chomp(':')
            # Verify that the digest algorithm is known to longleaf
            if !DigestHelper.is_known_algorithm?(current_alg)
              self.fail("Manifest specifies unknown digest algorithm: #{current_alg}")
            end
          else
            if current_alg.nil?
              self.fail("Manifest with unknown checksums encountered, an algorithm must be specified")
            end
            entry_parts = line.split(' ', 2)
            if entry_parts.length != 2
              self.fail("Invalid manifest entry: #{line}")
            end

            digests_mapping[entry_parts[1]][current_alg] = entry_parts[0]
          end
        end
      end

      digests_mapping
    end

    # Parses the provided options to create a selector for registered files
    # @param options [Hash] command options
    # @param app_config_manager [ApplicationConfigManager] app config manager
    # @return selector
    def self.create_registered_selector(options, app_config_manager)
      there_can_be_only_one("Only one of the following selection options may be provided: -l, -f, -s",
          options, :file, :location, :from_list)
          
      if !options[:from_list].nil?
        file_paths = read_from_list(options[:from_list])
        return RegisteredFileSelector.new(file_paths: file_paths, app_config: app_config_manager)
      elsif !options[:file].nil?
        file_paths = options[:file].split(/\s*,\s*/)
        return RegisteredFileSelector.new(file_paths: file_paths, app_config: app_config_manager)
      elsif !options[:location].nil?
        storage_locations = options[:location].split(/\s*,\s*/)
        return RegisteredFileSelector.new(storage_locations: storage_locations, app_config: app_config_manager)
      else
        logger.failure("Must provide one of the following file selection options: -l, -f, or -s")
        exit 1
      end
    end
    
    # Parses the -l from_list option, reading the list of files specified either from the provided
    # file path or STDIN
    # @param from_list option value, either a file path or "@-"
    # @return list of files from the from_list
    def self.read_from_list(from_list)
      from_list = from_list.strip
      if from_list.empty?
        logger.failure("List parameter must not be empty")
        exit 1
      end
      
      if from_list == '@-'
        source_stream = $stdin
      else
        begin
          source_stream = File.new(from_list)
        rescue Errno::ENOENT
          logger.failure("Specified list file does not exist: #{from_list}")
          exit 1
        end
      end
      
      lines = []
      source_stream.each_line do |line|
        lines << line.strip
      end
      
      if lines.empty?
        logger.failure("File list is empty, must provide one or more files for this operation")
        exit 1
      end
      lines
    end

    def self.fail(message)
      logger.failure(message)
      exit 1
    end
  end
end
