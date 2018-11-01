require 'longleaf/logging'

# Parent class for longleaf commands
module Longleaf
  class AbstractCommand
    include Longleaf::Logging
    
    # Record a successful operation to the output and the overall status of this command.
    # @param args [Array] arguments to pass to logger
    def record_success(*args)
      logger.success(*args)
      if @return_status.nil? || @return_status == 0
        @return_status = 0
      else
        @return_status = 2
      end
    end
    
    # Record a failed operation to the output and the overall status of this command.
    # @param args [Array] arguments to pass to logger
    def record_failure(*args)
      logger.failure(*args)
      if @return_status.nil? || @return_status == 1
        @return_status = 1
      else
        @return_status = 2
      end
    end
    
    # @return [Integer] the return status for this command, where 0 indicates success,
    #    1 indicates failure, and 2 indicates partial failure
    def return_status
      @return_status = 0 if @return_status.nil?
      @return_status
    end
  end
end