module ServiceBroker
  module Filters
    # Parent of every input type: holds the options and checks one value.
    class Base
      SHARED_OPTIONS = %i[default discard_nils discard_empty discard_invalid error_key transform
                          coerce].freeze

      attr_reader :options, :name

      def self.default_options
        { nils: false }
      end

      def self.allows_empty_is_nil?
        default_options.key?(:empty_is_nil)
      end

      def initialize(name, options = {}, &block)
        @name = name
        check_options!(options)
        @options = self.class.default_options.merge(options)
        @block = block
        after_declaration
      end

      # Returns [value, error code or nil].
      def filter(value)
        [value, nil]
      end

      def default?
        options.key?(:default)
      end

      def default
        value = options[:default]
        return value.call if value.respond_to?(:call)
        return value if value.frozen? || !value.respond_to?(:dup)

        value.dup
      end

      def discard_nils?
        options[:discard_nils] || !options[:nils]
      end

      def discard_empty?
        options[:discard_empty]
      end

      def discard_invalid?
        options[:discard_invalid]
      end

      def error_key
        options[:error_key] || name
      end

      # Applies the coerce option to the value as it came in, before the type check.
      def coerce_value(value)
        rule = options[:coerce]
        return [value, nil] if rule.nil?

        [rule.respond_to?(:call) ? rule.call(value) : value.public_send(rule), nil]
      rescue StandardError
        [value, :coerce]
      end

      # Applies the transform option to one checked value.
      def transform(value)
        rule = options[:transform]
        return [value, nil] if rule.nil?

        [rule.respond_to?(:call) ? rule.call(value) : value.public_send(rule), nil]
      rescue StandardError
        [value, :transform]
      end

      private

      attr_reader :block

      def after_declaration; end

      def check_options!(options)
        allowed = self.class.default_options.keys + SHARED_OPTIONS + extra_allowed_options(options)
        unknown = options.keys.map(&:to_sym) - allowed
        return if unknown.empty?

        raise DeclarationError,
              "input #{name} does not accept #{unknown.join(', ')}"
      end

      # An array with of: carries the options of its element type.
      def extra_allowed_options(options)
        element = options[:of]
        return [] unless element

        klass = Filters.lookup(element)
        klass ? klass.default_options.keys + SHARED_OPTIONS : []
      end

      def nil_answer
        options[:nils] ? [nil, nil] : [nil, :nils]
      end
    end
  end
end
