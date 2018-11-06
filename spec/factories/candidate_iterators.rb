require 'longleaf/candidates/service_candidate_filesystem_iterator'

FactoryBot.define do
  factory(:service_candidate_filesystem_iterator, class: Longleaf::ServiceCandidateFilesystemIterator) do
    file_selector { nil }
    event { 'verify' }
    app_config { nil }
    
    initialize_with { new(file_selector, event, app_config) }
  end
end