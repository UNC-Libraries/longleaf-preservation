require 'time'

module Longleaf
  # Helper methods for interacting with dates/timestamps on services
  class ServiceDateHelper
    
    # Adds the amount of time from modifier to the provided timestamp
    # @param timestamp [String] ISO-8601 timestamp string
    # @param modifier [String] amount of time to add to the timestamp. It must follow the syntax
    # "<quantity> <time unit>", where quantity must be a positive whole number and time unit
    # must be second, minute, hour, day, week, month or year (unit may be plural).
    # Any info after a comma will be ignored.
    # @return [String] the original timestamp in ISO-8601 format with the provided amount of time added.
    def self.add_to_timestamp(timestamp, modifier)
      if modifier =~ /^(\d+) *(second|minute|hour|day|week|month|year)s?(,.*)?/
        value = $1.to_i
        unit = $2
      else
        raise ArgumentError.new("Cannot parse time modifier #{modifier}")
      end
      
      datetime = Time.iso8601(timestamp)
      case unit
      when 'second'
        unit_modifier = 1
      when 'minute'
        unit_modifier = 60
      when 'hour'
        unit_modifier = 3600
      when 'day'
        unit_modifier = 24 * 3600
      when 'week'
        unit_modifier = 7 * 24 * 3600
      when 'month'
        unit_modifier = 30 * 24 * 3600
      when 'year'
        unit_modifier = 365 * 24 * 3600
      end
      
      modified_time = datetime + (value * unit_modifier)
      modified_time.iso8601
    end
  end
end