require 'logger'

module Longleaf
  module Logging
    # Logger which directs messages to stdout and/or stderr, depending on the nature of the message.
    # Status logging, which includes standard logger methods, goes to STDERR.
    # Operation success and failure messages go to STDOUT, and to STDERR at info level.
    class RedirectingLogger
      # @param [Boolean] failure_only If set to true, only failure messages will be output to STDOUT
      # @param log_level [String] logger level used for output to STDERR
      # @param log_format [String] format string for log entries to STDERR. There are 4 variables available
      #    for inclusion in the output: severity, datetime, progname, msg. Variables must be wrapped in %{}.
      # @param datetime_format [String] datetime formatting string used for logger dates appearing in STDERR.
      def initialize(failure_only: false, log_level: 'WARN', log_format: nil, datetime_format: nil)
        @stderr_log = Logger.new($stderr)
        @stderr_log.level = log_level
        @stderr_log.datetime_format = datetime_format
        @log_format = log_format
        if @log_format.nil?
          @stderr_log.formatter = proc do |severity, datetime, progname, msg|
            formatted_date = @stderr_log.datetime_format.nil? ? datetime : datetime.strftime(datetime_format)
            "#{severity} [#{formatted_date}]: #{msg}\n"
          end
        elsif @log_format.is_a?(String)
          @stderr_log.formatter = proc do |severity, datetime, progname, msg|
            # Make sure the format ends with a newline
            @log_format = @log_format + "\n" unless @log_format.end_with?("\n")

            formatted_date = @stderr_log.datetime_format.nil? ? datetime : datetime.strftime(datetime_format)
            @log_format % { :severity => severity, :datetime => formatted_date, :progname => progname, :msg => msg }
          end
        end

        @stdout_log = Logger.new($stdout)
        @stdout_log.formatter = proc do |severity, datetime, progname, msg|
          "#{msg}\n"
        end
        if failure_only
          @stdout_log.level = 'warn'
        else
          @stdout_log.level = 'info'
        end
      end

      def debug(progname = nil, &block)
        @stderr_log.debug(progname, &block)
      end

      def info(progname = nil, &block)
        @stderr_log.info(progname, &block)
      end

      def warn(progname = nil, &block)
        @stderr_log.warn(progname, &block)
      end

      def error(progname = nil, &block)
        @stderr_log.error(progname, &block)
      end

      def fatal(progname = nil, &block)
        @stderr_log.fatal(progname, &block)
      end

      def unknown(progname = nil, &block)
        @stderr_log.unknown(progname, &block)
      end

      # Logs a success message to STDOUT, as well as STDERR at info level.
      #
      # @param [String] eventOrMessage name of the preservation event which succeeded,
      #    or the message to output if it is the only parameter. Required.
      # @param file_name [String] file name which is the subject of this message.
      # @param message [String] descriptive message to accompany this output
      # @param service [String] name of the service which executed.
      def success(eventOrMessage, file_name = nil, message = nil, service = nil)
        outcome('SUCCESS', eventOrMessage, file_name, message, service)
      end

      # Logs a failure message to STDOUT, as well as STDERR at info level.
      # If an error was provided, it is logged to STDERR at error level.
      # @param eventOrMessage [String] name of the preservation event which failed,
      #    or the message to output if it is the only parameter.
      # @param file_name [String] file name which is the subject of this message.
      # @param message [String] descriptive message to accompany this output
      # @param service [String] name of the service which executed.
      # @param error [Error] error which occurred
      def failure(eventOrMessage, file_name = nil, message = nil, service = nil, error: nil)
        text = outcome_text('FAILURE', eventOrMessage, file_name, message, service, error)
        @stdout_log.warn(text)

        @stderr_log.info(text)
        @stderr_log.error("#{error.message}") unless error.nil?
        @stderr_log.error("#{error.backtrace.to_s}") unless error.nil? || error.backtrace.nil?
      end

      # Logs an outcome message to STDOUT, as well as STDERR at info level.
      # If file_name and message are nil, eventOrMessage will be used as the message.
      #
      # @param outcome [String] The status of the outcome. Required.
      # @param eventOrMessage [String] name of the preservation event which was successful,
      #     or the message to output if it is the only parameter. Required.
      # @param file_name [String] file name which is the subject of this message.
      # @param message [String] descriptive message to accompany this output
      # @param service [String] name of the service which executed.
      # @param error [Error] error which occurred
      def outcome(outcome, eventOrMessage, file_name = nil, message = nil, service = nil, error = nil)
        text = outcome_text(outcome, eventOrMessage, file_name, message, service, error)
        @stdout_log.info(text)
        @stderr_log.info(text)
      end

      private
      def outcome_text(outcome, eventOrMessage, file_name = nil, message = nil, service = nil, error = nil)
        message_only = file_name.nil? && message.nil? && error.nil?

        text = "#{outcome}"

        if message_only
          text << ": #{eventOrMessage}"
        else
          text << " #{eventOrMessage}"
          text << "[#{service}]" unless service.nil?
          text << " #{file_name}" unless file_name.nil?
          msg = message || error&.message
          text << ": #{msg}" unless msg.nil?
        end
        text
      end
    end
  end
end
