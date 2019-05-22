require 'longleaf/logging'

module Longleaf
  # Helper methods for tracking and recording the overall outcome of a preservation event.
  module EventStatusTracking
    include Longleaf::Logging

    # Record a successful operation to the output and the overall status of this event.
    # @param args [Array] arguments to pass to logger
    def record_success(*args)
      logger.success(*args)
      track_success
    end

    # Update the status of this action with a success outcome.
    def track_success
      if @return_status.nil? || @return_status == 0
        @return_status = 0
      else
        @return_status = 2
      end
    end

    # Record a failed operation to the output and the overall status of this event.
    # @param args [Array] arguments to pass to logger
    def record_failure(*args)
      logger.failure(*args)
      track_failure
    end

    # Update the status of this action with a failure outcome.
    def track_failure
      if @return_status.nil? || @return_status == 1
        @return_status = 1
      else
        @return_status = 2
      end
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

    # @return [Integer] the return status for this event, where 0 indicates success,
    # 1 indicates failure, and 2 indicates partial failure
    def return_status
      @return_status = 0 if @return_status.nil?
      @return_status
    end
  end
end
