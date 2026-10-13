module ServiceBroker
  module Filters
    # Shared steps of date and time: blank handling, parsing, bounds.
    class Temporal < Base
      def self.default_options
        {
          nils: false,
          empty_is_nil: false,
          format: nil,
          after: nil,
          before: nil,
          on_or_after: nil,
          on_or_before: nil
        }
      end

      def filter(value)
        value = nil if options[:empty_is_nil] && value == ''
        return nil_answer if value.nil?
        return [value, :empty] if value == ''

        moment = coerce(value)
        return [value, code] if moment.nil?

        bound = bound_error(moment)
        bound ? [value, bound] : [moment, nil]
      end

      private

      def bound_error(moment)
        return :after if options[:after] && moment <= options[:after]
        return :before if options[:before] && moment >= options[:before]
        return :on_or_after if options[:on_or_after] && moment < options[:on_or_after]
        return :on_or_before if options[:on_or_before] && moment > options[:on_or_before]

        nil
      end

      def parse_text(value, parser, formatter)
        if options[:format]
          formatter.call(value, options[:format])
        else
          parser.call(value)
        end
      rescue ::ArgumentError, ::TypeError
        nil
      end
    end

    # Calendar day input.
    class Date < Temporal
      def code
        :date
      end

      private

      def coerce(value)
        return value.to_date if value.is_a?(::DateTime)
        return value if value.is_a?(::Date)
        return value.to_date if value.respond_to?(:to_date) && !value.is_a?(::String)
        return nil unless value.is_a?(::String)

        parse_text(value, ::Date.method(:parse), ::Date.method(:strptime))
      end
    end

    # Moment input.
    class Time < Temporal
      def code
        :time
      end

      private

      def coerce(value)
        return value if value.is_a?(::Time)
        return value.to_time if value.respond_to?(:to_time) && !value.is_a?(::String)
        return nil unless value.is_a?(::String)

        parse_text(value, ::Time.method(:parse), ::Time.method(:strptime))
      end
    end
  end
end
