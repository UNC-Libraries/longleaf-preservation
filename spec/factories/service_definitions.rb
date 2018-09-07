require 'longleaf/models/service_definition'
require 'longleaf/services/service_definition_manager'

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
end