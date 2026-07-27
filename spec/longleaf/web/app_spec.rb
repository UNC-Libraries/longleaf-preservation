require 'spec_helper'
require 'longleaf/web/app'

describe Longleaf::Web::App do
  def with_env(overrides)
    previous = overrides.each_with_object({}) do |(key, _value), memo|
      memo[key] = ENV[key]
    end
    overrides.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  describe '.configure_logging!' do
    it 'configures file-backed daily rotation when enabled' do
      with_env(
        'LONGLEAF_LOG_ROTATION' => 'daily',
        'LONGLEAF_LOG_DIR' => '/tmp/longleaf-logs',
        'LONGLEAF_LOG_LEVEL' => 'DEBUG',
        'LONGLEAF_LOG_FORMAT' => '%{msg}'
      ) do
        expect(Longleaf::Logging).to receive(:initialize_logger).with(
          false,
          'DEBUG',
          '%{msg}',
          nil,
          stdout_path: '/tmp/longleaf-logs/longleaf.log',
          stderr_path: '/tmp/longleaf-logs/longleaf-error.log',
          shift_age: 'daily'
        )

        described_class.configure_logging!
      end
    end

    it 'keeps stream-backed logging when rotation is disabled' do
      with_env(
        'LONGLEAF_LOG_ROTATION' => 'off',
        'LONGLEAF_LOG_LEVEL' => 'INFO',
        'LONGLEAF_LOG_FORMAT' => nil
      ) do
        expect(Longleaf::Logging).to receive(:initialize_logger).with(false, 'INFO', nil, nil)

        described_class.configure_logging!
      end
    end
  end

  describe '.load_app_manager' do
    before do
      allow(Longleaf::ApplicationConfigDeserializer).to receive(:deserialize)
        .and_raise(Longleaf::ConfigurationError, 'bad config')
      allow(Longleaf::Logging.logger).to receive(:warn)
    end

    it 'logs configuration failures through the application logger' do
      with_env('LONGLEAF_CFG' => '/tmp/longleaf.yml') do
        described_class.load_app_manager
      end

      expect(Longleaf::ApplicationConfigDeserializer).to have_received(:deserialize).with('/tmp/longleaf.yml')
      expect(Longleaf::Logging.logger).to have_received(:warn)
        .with('Failed to load Longleaf application configuration: bad config')
    end
  end
end
