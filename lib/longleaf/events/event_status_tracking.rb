require 'longleaf/logging'

module Longleaf
  # Helper methods for tracking and recording the overall outcome of a preservation event.
  module EventStatusTracking
    include Longleaf::Logging

    # Record a successful operation to the output and the overall status of this event.
    # @param args [Array] arguments to pass to logger; args[1] is treated as the file path
    def record_success(*args)
      logger.success(*args)
      track_success(args[1])
    end

    # Update the status of this action with a success outcome.
    # @param path [String, nil] optional file path to record in the success list
    def track_success(path = nil)
      if @return_status.nil? || @return_status == 0
        @return_status = 0
      else
        @return_status = 2
      end
      @success_paths ||= []
      @success_paths << path unless path.nil?
    end

    # Record a failed operation to the output and the overall status of this event.
    # @param args [Array] arguments to pass to logger; args[1] is treated as the file path
    def record_failure(*args, **kwargs)
      logger.failure(*args, **kwargs)
      track_failure(args[1])
    end

    # Update the status of this action with a failure outcome.
    # @param path [String, nil] optional file path to record in the failure list
    def track_failure(path = nil)
      if @return_status.nil? || @return_status == 1
        @return_status = 1
      else
        @return_status = 2
      end
      @failure_paths ||= []
      @failure_paths << path unless path.nil?
    end

    # Update the status of this action with the provided outcome status number.
    # @param status [Integer] outcome status
    def track_status(status)
      if status == 2
        @return_status = 2
      elsif status == 0
        track_success
      elsif status == 1
        track_failure
      end
    end

    # Merge the path outcomes from another EventStatusTracking object into this one.
    # Useful for aggregating paths from individual events into a parent command.
    # Does not alter the return_status; use track_status for that.
    # @param other [#success_paths, #failure_paths] another tracking object
    def merge_outcome(other)
      @success_paths ||= []
      @failure_paths ||= []
      @success_paths.concat(other.success_paths)
      @failure_paths.concat(other.failure_paths)
    end

    # Returns the accumulated paths categorised by outcome.
    # @param event_name [String] name of the event, included in the result
    # @return [Hash] e.g. { event: 'register', success: [...], failure: [...] }
    def outcome_summary(event_name)
      {
        event:   event_name,
        success: (@success_paths || []).compact,
        failure: (@failure_paths || []).compact
      }
    end

    # @return [Array<String>] paths that were processed successfully
    def success_paths
      @success_paths || []
    end

    # @return [Array<String>] paths that were processed with failure
    def failure_paths
      @failure_paths || []
    end

    # @return [Integer] the return status for this event, where 0 indicates success,
    # 1 indicates failure, and 2 indicates partial failure
    def return_status
      @return_status = 0 if @return_status.nil?
      @return_status
    end
  end
end
