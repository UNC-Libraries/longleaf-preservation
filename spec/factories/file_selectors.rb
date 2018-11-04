require 'longleaf/candidates/file_selector'

FactoryBot.define do
  factory(:file_selector, class: Longleaf::FileSelector) do
    
    initialize_with { new(attributes) }
  end
end