require 'longleaf/models/service_definition'
require 'longleaf/services/application_config_manager'

FactoryBot.define do
  factory(:application_config_manager, class: Longleaf::ApplicationConfigManager) do
    transient do
      config {
        {
          'locations' => {},
        'services' => {},
        'service_mappings' => {}
        }
      }
    end

    initialize_with { new(config) }
  end
end
