module ServiceBroker
  module Filters
    # Text input: coerces plain scalars, cleans control characters, checks size.
    class String < Base
      SCALARS = [TrueClass, FalseClass, ::Integer, ::Float, ::BigDecimal, ::Symbol].freeze
      CONTROL = /[^[:print:]\t\r\n]+/

      def self.default_options
        {
          strip: true,
          strict: false,
          nils: false,
          empty_is_nil: false,
          empty: false,
          min_length: nil,
          max_length: nil,
          matches: nil,
          in: nil,
          allow_control_characters: false
        }
      end

      def filter(value)
        value = nil if options[:empty_is_nil] && value == ''
        return nil_answer if value.nil?

        value = coerce(value)
        return [value, :string] unless value.is_a?(::String)

        value = clean(value)
        return options[:empty] ? [value, nil] : [value, :empty] if value.empty?

        code = size_error(value) || choice_error(value)
        code ? [value, code] : [value, nil]
      end

      private

      def coerce(value)
        return value if options[:strict]
        return value.to_s if SCALARS.any? { |klass| value.is_a?(klass) }

        value
      end

      def clean(value)
        value = value.gsub(CONTROL, '') unless options[:allow_control_characters]
        value = value.strip if options[:strip]

        value
      end

      def size_error(value)
        return :min_length if options[:min_length] && value.length < options[:min_length]
        return :max_length if options[:max_length] && value.length > options[:max_length]

        nil
      end

      def choice_error(value)
        return :in if options[:in] && !options[:in].include?(value)
        return :matches if options[:matches] && !options[:matches].match?(value)

        nil
      end
    end
  end
end
