require 'longleaf/services/system_config_manager'

FactoryBot.define do
  
  factory(:system_config_manager, class: Longleaf::SystemConfigManager) do
    transient do
      config { {} }
    end
    app_config_manager { build(:application_config_manager) }

    initialize_with { new(config, app_config_manager) }
  end
end