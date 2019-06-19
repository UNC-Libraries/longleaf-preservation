module Longleaf
  module ConfigValidatorHelpers
    def fails_validation_with_error(validator, *error_messages)
      result = validator.validate_config
      expect(result.valid?).to be false
      error_messages.each do |error_message|
        expect(result.errors).to include(error_message)
      end
    end

    def passes_validation(validator)
      result = validator.validate_config
      expect(result.valid?).to eq(true), "expected validation to pass, but received errors:\n#{result.errors&.join("\n")}"
    end
  end
end
