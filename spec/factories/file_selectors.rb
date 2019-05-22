require 'longleaf/candidates/file_selector'
require 'longleaf/candidates/registered_file_selector'

FactoryBot.define do
  factory(:file_selector, class: Longleaf::FileSelector) do
    initialize_with { new(attributes) }
  end
end

FactoryBot.define do
  factory(:registered_file_selector, class: Longleaf::RegisteredFileSelector) do
    initialize_with { new(attributes) }
  end
end
