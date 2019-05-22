require 'longleaf/logging/redirecting_logger'

FactoryBot.define do
  factory(:logger, class: Longleaf::Logging::RedirectingLogger) do
    failure_only { false }
    log_level { 'WARN' }
    log_format { nil }
    datetime_format { nil }

    trait :debug do
      log_level { 'DEBUG' }
    end

    initialize_with { new(attributes) }
  end
end
