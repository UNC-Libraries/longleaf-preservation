require 'spec_helper'
require 'longleaf/logging/redirecting_logger'
require 'logger'

describe Longleaf::Logging::RedirectingLogger do
  describe '.debug' do
    context 'with log level of debug' do
      let(:logger) { build(:logger, :debug) }

      it 'logs to STDERR at debug level' do
        expect { logger.debug('test') }.to output(/DEBUG.*test/).to_stderr
      end
    end

    context 'with custom date format' do
      let(:logger) { build(:logger, :debug, datetime_format: '%Y-%m-%d') }
      let(:date) { Time.now.strftime('%Y-%m-%d') }

      specify { expect { logger.debug('test') }.to output(/DEBUG \[#{date}\]: test/).to_stderr }
    end

    context 'with custom formatter and date' do
      let(:logger) { build(:logger, :debug, datetime_format: '%Y-%m-%d', log_format: '%{datetime}|%{msg}') }
      let(:date) { Time.now.strftime('%Y-%m-%d') }

      specify { expect { logger.debug('test') }.to output("#{date}|test\n").to_stderr }
    end
  end

  describe '.info' do
    let(:logger) { build(:logger, :debug) }

    it 'logs to STDERR at info level' do
      expect { logger.info('test') }.to output(/INFO.*test/).to_stderr
    end
  end

  describe '.warn' do
    let(:logger) { build(:logger, :debug) }

    it 'logs to STDERR at warn level' do
      expect { logger.warn('test') }.to output(/WARN.*test/).to_stderr
    end
  end

  describe '.error' do
    let(:logger) { build(:logger, :debug) }

    it 'logs to STDERR at error level' do
      expect { logger.error('test') }.to output(/ERROR.*test/).to_stderr
    end
  end

  describe '.fatal' do
    let(:logger) { build(:logger, :debug) }

    it 'logs to STDERR at fatal level' do
      expect { logger.fatal('test') }.to output(/FATAL.*test/).to_stderr
    end
  end

  describe '.unknown' do
    let(:logger) { build(:logger, :debug) }

    it 'logs to STDERR at unknown level' do
      expect { logger.unknown('test') }.to output(/ANY.*test/).to_stderr
    end
  end

  describe '.success' do
    context 'with log level debug' do
      let(:logger) { build(:logger, :debug) }

      context 'with message' do
        specify { expect { logger.success('good') }.to output(/SUCCESS: good/).to_stdout }
        specify { expect { logger.success('good') }.to output(/INFO.*SUCCESS: good/).to_stderr }
      end

      context 'with event and file' do
        specify {
          expect { logger.success('register', '/path/to/file') }.to output(
            /SUCCESS register \/path\/to\/file/).to_stdout
        }
        specify {
          expect { logger.success('register', '/path/to/file') }.to output(
            /INFO.*SUCCESS register \/path\/to\/file/).to_stderr
        }
      end

      context 'with event, file, message and service' do
        specify {
          expect { logger.success('preserve', '/path/to/file', 'good stuff', 'my_service') }.to output(
            /SUCCESS preserve\[my_service\] \/path\/to\/file: good stuff/).to_stdout
        }
        specify {
          expect { logger.success('preserve', '/path/to/file', 'good stuff', 'my_service') }.to output(
            /INFO.*SUCCESS preserve\[my_service\] \/path\/to\/file: good stuff/).to_stderr
        }
      end
    end

    context 'with failure_only' do
      let(:logger) { build(:logger, :debug, failure_only: true) }

      context 'with event and file' do
        specify { expect { logger.success('register', '/path/to/file') }.to_not output.to_stdout }
        specify {
          expect { logger.success('register', '/path/to/file') }.to output(
            /INFO.*SUCCESS register \/path\/to\/file/).to_stderr
        }
      end
    end
  end

  describe '.failure' do
    context 'with log level debug' do
      let(:logger) { build(:logger, :debug) }

      context 'with message' do
        specify { expect { logger.failure('bad') }.to output(/FAILURE: bad/).to_stdout }
        specify { expect { logger.failure('bad') }.to output(/INFO.*FAILURE: bad/).to_stderr }
      end

      context 'with event, file, message and service' do
        specify {
          expect { logger.failure('preserve', '/path/to/file', 'bad stuff', 'my_service') }.to output(
            /FAILURE preserve\[my_service\] \/path\/to\/file: bad stuff/).to_stdout
        }
        specify {
          expect { logger.failure('preserve', '/path/to/file', 'bad stuff', 'my_service') }.to output(
            /INFO.*FAILURE preserve\[my_service\] \/path\/to\/file: bad stuff/).to_stderr
        }
      end

      context 'with event, file and raised error' do
        specify do
          begin
            raise StandardError.new('Something terrible')
          rescue StandardError => error
            expect { logger.failure('register', '/path/to/file', error: error) }.to output(
                /FAILURE register \/path\/to\/file: Something terrible/).to_stdout
          end
        end
        specify do
          begin
            raise StandardError.new('Something terrible')
          rescue StandardError => error
            expect { logger.failure('register', '/path/to/file', error: error) }.to output(
                /INFO.*FAILURE register \/path\/to\/file.*\nERROR.*Something terrible/).to_stderr
          end
        end
      end

      context 'with error and message' do
        let(:error) { StandardError.new('Something terrible') }

        specify {
          expect { logger.failure('register', '/path/to/file', 'A message', error: error) }.to output(
            /FAILURE register \/path\/to\/file: A message/).to_stdout
        }
        specify {
          expect { logger.failure('register', '/path/to/file', 'A message', error: error) }.to output(
            /INFO.*FAILURE register \/path\/to\/file: A message/).to_stderr
        }
        specify {
          expect { logger.failure('register', '/path/to/file', 'A message', error: error) }.to output(
            /ERROR.*Something terrible/).to_stderr
        }
      end
    end

    context 'with failure_only' do
      let(:logger) { build(:logger, :debug, failure_only: true) }

      context 'with event and file' do
        specify {
          expect { logger.failure('register', '/path/to/file') }.to output(
            /FAILURE register \/path\/to\/file/).to_stdout
        }
        specify {
          expect { logger.failure('register', '/path/to/file') }.to output(
            /INFO.*FAILURE register \/path\/to\/file/).to_stderr
        }
      end
    end
  end
end
