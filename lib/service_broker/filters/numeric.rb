module ServiceBroker
  module Filters
    # Shared steps of the 3 numeric types: blank handling, bounds, choice.
    class Numeric < Base
      def self.default_options
        { nils: false, empty_is_nil: false, min: nil, max: nil, in: nil }
      end

      def filter(value)
        value = nil if options[:empty_is_nil] && value == ''
        return nil_answer if value.nil?
        return [value, :empty] if value == ''

        number = coerce(value)
        return [value, code] if number.nil?

        bound = bound_error(number)
        return [number, bound] if bound
        return [number, :in] if options[:in] && !options[:in].include?(number)

        [number, nil]
      end

      private

      def bound_error(number)
        return :min if options[:min] && number < options[:min]
        return :max if options[:max] && number > options[:max]

        nil
      end
    end

    # Whole number input.
    class Integer < Numeric
      PATTERN = /\A[+-]?\d+\z/

      def code
        :integer
      end

      private

      def coerce(value)
        return value if value.is_a?(::Integer) && !value.is_a?(TrueClass)
        return value.to_i if value.is_a?(::String) && PATTERN.match?(value)

        nil
      end
    end

    # Binary fraction input.
    class Float < Numeric
      PATTERN = /\A[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?\z/

      def code
        :float
      end

      private

      def coerce(value)
        return value if value.is_a?(::Float)
        return value.to_f if value.is_a?(::Integer) || value.is_a?(::BigDecimal) || value.is_a?(::Rational)
        return value.to_f if value.is_a?(::String) && PATTERN.match?(value)

        nil
      end
    end

    # Exact fraction input: keeps the precision a Float would lose.
    class Decimal < Numeric
      def code
        :decimal
      end

      private

      def coerce(value)
        return value if value.is_a?(::BigDecimal)
        return BigDecimal(value, 0) if value.is_a?(::Rational)
        return BigDecimal(value) if value.is_a?(::Integer)
        return BigDecimal(value) if value.is_a?(::String) && Float::PATTERN.match?(value)

        nil
      end
    end
  end
end
