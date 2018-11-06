require 'longleaf/models/service_record'
require 'longleaf/models/metadata_record'

FactoryBot.define do
  factory(:service_record, class: Longleaf::ServiceRecord) do
    properties { {} }
    
    initialize_with { new(attributes) }
    
    trait :timestamp_now do
      timestamp { Time.now.iso8601 }
    end
  end
  
  factory(:metadata_record, class: Longleaf::MetadataRecord) do
    properties { {} }
    services { {} }
    
    initialize_with { new(attributes) } 
    
    trait :multiple_services do
      services {
        {
          'service_1': build(:service_record, timestamp: '2018-01-01T01:00:00.000Z'),
          'service_2': build(:service_record, timestamp: '2018-01-01T02:00:00.000Z', properties: { 'service_prop' => 'value' })
        }
      }
    end
  end
end