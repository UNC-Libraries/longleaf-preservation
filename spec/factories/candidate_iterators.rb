require 'longleaf/candidates/service_candidate_filesystem_iterator'
require 'longleaf/candidates/service_candidate_index_iterator'

FactoryBot.define do
  factory(:service_candidate_filesystem_iterator, class: Longleaf::ServiceCandidateFilesystemIterator) do
    file_selector { nil }
    event { 'preserve' }
    app_config { nil }
    force { false }

    initialize_with { new(file_selector, event, app_config, force) }
  end
end

FactoryBot.define do
  factory(:service_candidate_index_iterator, class: Longleaf::ServiceCandidateIndexIterator) do
    file_selector { nil }
    event { 'preserve' }
    app_config { nil }
    force { false }

    initialize_with { new(file_selector, event, app_config, force) }
  end
end
