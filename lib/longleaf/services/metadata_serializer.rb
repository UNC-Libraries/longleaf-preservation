require 'yaml'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'
require 'longleaf/helpers/digest_helper'
require 'longleaf/errors'
require 'longleaf/logging'
require 'pathname'
require "tempfile"

module Longleaf
  # Service which serializes MetadataRecord objects
  class MetadataSerializer
    extend Longleaf::Logging
    MDF ||= MDFields

    # Serialize the contents of the provided metadata record to the specified path
    #
    # @param metadata [MetadataRecord] metadata record to serialize. Required.
    # @param file_path [String] path to write the file to. Required.
    # @param format [String] format to serialize the metadata in. Default is 'yaml'.
    # @param digest_algs [Array] if provided, sidecar digest files for the metadata file
    #    will be generated for each algorithm.
    def self.write(metadata:, file_path:, format: 'yaml', digest_algs: [])
      raise ArgumentError.new('metadata parameter must be a MetadataRecord') \
          unless metadata.class == MetadataRecord

      case format
      when 'yaml'
        content = to_yaml(metadata)
      else
        raise ArgumentError.new("Invalid serialization format #{format} specified")
      end

      atomic_write(file_path, content, digest_algs)
    end

    # @param metadata [MetadataRecord] metadata record to transform
    # @return [String] a yaml representation of the provided MetadataRecord
    def self.to_yaml(metadata)
      props = to_hash(metadata)
      props.to_yaml
    end

    # Create a hash representation of the given MetadataRecord file
    # @param metadata [MetadataRecord] metadata record to transform into a hash
    def self.to_hash(metadata)
      props = Hash.new

      data = Hash.new.merge(metadata.properties)
      data[MDF::REGISTERED_TIMESTAMP] = metadata.registered if metadata.registered
      data[MDF::DEREGISTERED_TIMESTAMP] = metadata.deregistered if metadata.deregistered
      data[MDF::CHECKSUMS] = metadata.checksums unless metadata.checksums && metadata.checksums.empty?
      data[MDF::FILE_SIZE] = metadata.file_size unless metadata.file_size.nil?
      data[MDF::LAST_MODIFIED] = metadata.last_modified if metadata.last_modified
      data[MDF::PHYSICAL_PATH] = metadata.physical_path if metadata.physical_path

      props[MDF::DATA] = data

      services = Hash.new
      metadata.list_services.each do |name|
        service = metadata.service(name)
        service[MDF::STALE_REPLICAS] = service.stale_replicas if service.stale_replicas
        service[MDF::SERVICE_TIMESTAMP] = service.timestamp unless service.timestamp.nil?
        service[MDF::RUN_NEEDED] = service.run_needed if service.run_needed
        services[name] = service.properties unless service.properties.empty?
      end

      props[MDF::SERVICES] = services

      props
    end

    # @param format [String] encoding format used for metadata file
    # @return [String] the suffix used to indicate that a file is a metadata file in the provided encoding
    # @raise [ArgumentError] raised if the provided format is not a supported metadata encoding format
    def self.metadata_suffix(format: 'yaml')
      case format
      when 'yaml'
        '-llmd.yaml'
      else
        raise ArgumentError.new("Invalid serialization format #{format} specified")
      end
    end

    # Safely writes the new metadata file and its digests.
    # It does so by first writing the content and its digests to temp files,
    # then making the temp files the current version of the file.
    # Attempts to clean up new data in the case of failure.
    def self.atomic_write(file_path, content, digest_algs)
      # Fill in parent directories if they do not exist
      parent_dir = Pathname(file_path).parent
      parent_dir.mkpath unless parent_dir.exist?

      file_path = file_path.path if file_path.respond_to?(:path)

      # If file does not already exist, then simply write it
      if !File.exist?(file_path)
        File.write(file_path, content)
        write_digests(file_path, content, digest_algs)
        return
      end

      # Updating file, use safe atomic write
      File.open(file_path) do |original_file|
        original_file.flock(File::LOCK_EX)

        base_name = File.basename(file_path)
        old_renamed = nil
        Tempfile.open(base_name, parent_dir) do |temp_file|
          begin
            # Write content to temp file
            temp_file.write(content)
            temp_file.close

            temp_path = temp_file.path

            # Set permissions of new file to match old if it exists
            old_stat = File.stat(file_path)
            set_perms(temp_path, old_stat)

            # Produce digest files for the temp file
            digest_paths = write_digests(temp_path, content, digest_algs)
            
            # Move the old file to a temp path in case it needs to be restored
            old_renamed = temp_path + ".old"
            File.rename(file_path, old_renamed)
            
            # Move move the new file into place as the new main file
            File.rename(temp_path, file_path)
          rescue => e
            # Attempt to restore old file if it had already been moved
            if !old_renamed.nil? && !File.exist?(file_path)
              File.rename(old_renamed, file_path)
            end
            # Cleanup the temp file and any digest files written for it
            temp_file.delete if File.exist?(temp_file.path)
            unless digest_paths.nil?
              digest_paths.each do |digest_path|
                File.delete(digest_path)
              end
            end
            raise e
          end

          # Cleanup all existing digest files, in case the set of algorithms has changed
          cleanup_digests(file_path)
          # Move new digests into place
          digest_paths.each do |digest_path|
            File.rename(digest_path, digest_path.sub(temp_path, file_path))
          end
          # Cleanup the old file
          File.delete(old_renamed)
        end
      end
    end

    def self.set_perms(file_path, stat_info)
      if stat_info
        # Set correct permissions on new file
        begin
          File.chown(stat_info.uid, stat_info.gid, file_path)
          # This operation will affect filesystem ACL's
          File.chmod(stat_info.mode, file_path)
        rescue Errno::EPERM, Errno::EACCES
          # Changing file ownership failed, moving on.
          return false
        end
      end
      true
    end

    # Deletes all known digest files for the provided file path
    def self.cleanup_digests(file_path)
      DigestHelper::KNOWN_DIGESTS.each do |alg|
        digest_path = "#{file_path}.#{alg}"
        File.delete(digest_path) if File.exist?(digest_path)
      end
    end

    def self.write_digests(file_path, content, digests)
      return [] if digests.nil? || digests.empty?

      digest_paths = Array.new

      digests.each do |alg|
        digest_class = DigestHelper::start_digest(alg)
        result = digest_class.hexdigest(content)
        digest_path = "#{file_path}.#{alg}"

        File.write(digest_path, result)

        digest_paths.push(digest_path)

        self.logger.debug("Generated #{alg} digest for metadata file #{file_path}: #{digest_path} #{result}")
      end

      digest_paths
    end

    private_class_method :cleanup_digests
    private_class_method :write_digests
    private_class_method :atomic_write
  end
end
