require 'longleaf/candidates/service_candidate_filesystem_iterator'
require 'longleaf/candidates/service_candidate_index_iterator'

module Longleaf
  # Service which locates files that have services which need to be performed on them.
  class ServiceCandidateLocator
    def initialize(app_config)
      @app_config = app_config
    end

    # Get a iterator of the candidates matching the given FileSelector which need services run.
    # @param file_selector [FileSelector] selector identifying the files to pull candidates from.
    # @return an iterator
    def candidate_iterator(file_selector, event, force = false)
      if @app_config.index_manager.using_index?
        ServiceCandidateIndexIterator.new(file_selector, event, @app_config, force)
      else
        # Get filesystem based implementation
        ServiceCandidateFilesystemIterator.new(file_selector, event, @app_config, force)
      end
    end
  end
end
