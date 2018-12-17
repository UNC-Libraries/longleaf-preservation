require 'longleaf/models/service_definition'
require 'longleaf/services/service_definition_manager'
require 'longleaf/services/service_mapping_manager'
require 'longleaf/services/service_manager'
require 'longleaf/services/service_class_cache'

FactoryBot.define do
  factory(:service_definition, class: Longleaf::ServiceDefinition) do
    name { 'p_serv' }
    work_script { 'preserve.rb' }
    
    initialize_with { new(attributes) }
  end
  
  factory(:service_definition_manager, class: Longleaf::ServiceDefinitionManager) do
    config { {} }

    initialize_with { new(config) }
  end
  
  factory(:service_mapping_manager, class: Longleaf::ServiceMappingManager) do
    config { {} }

    initialize_with { new(config) }
  end
  
  factory(:service_manager, class: Longleaf::ServiceManager) do
    transient do
      config { {} }
    end
    
    definition_manager { build(:service_definition_manager, config: config) }
    mapping_manager { build(:service_mapping_manager, config: config) }

    initialize_with { new(attributes) }
  end
  
  factory(:service_class_cache, class: Longleaf::ServiceClassCache) do
    initialize_with { new }
  end
end