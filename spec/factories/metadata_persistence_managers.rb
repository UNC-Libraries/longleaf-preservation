require 'longleaf/services/metadata_persistence_manager'

FactoryBot.define do
  
  factory(:metadata_persistence_manager, class: Longleaf::MetadataPersistenceManager) do
    sys_manager { nil }

    initialize_with { new(sys_manager) }
  end
end