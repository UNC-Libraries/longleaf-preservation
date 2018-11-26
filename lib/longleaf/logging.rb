require 'longleaf/logging/redirecting_logger'

module Longleaf
  # Module for access logging within longleaf
  module Logging
    # Get the main logger for longleaf
    def logger
      Logging.logger
    end
    
    # Get the main logger for longleaf
    def self.logger
      @logger ||= RedirectingLogger.new
    end
  
    def initialize_logger(failure_only, log_level, log_format, datetime_format)
      Logging.initialize_logger(failure_only, log_level, log_format, datetime_format)
    end
  
    def self.initialize_logger(failure_only, log_level, log_format, datetime_format)
      @logger = RedirectingLogger.new(failure_only: failure_only,
          log_level: log_level,
          log_format: log_format,
          datetime_format: datetime_format)
    end
  end
end