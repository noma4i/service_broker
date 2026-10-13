module ServiceBroker
  module Filters
    # Input out of a named list: a string or a symbol in, a symbol of the list out.
    class Enum < Base
      def self.default_options
        { nils: false, empty_is_nil: false, values: nil }
      end

      def filter(value)
        value = nil if options[:empty_is_nil] && value == ''
        return nil_answer if value.nil?
        return [value, :empty] if value == ''

        name = case value
               when ::Symbol then value
               when ::String then value.to_sym
               end
        return [value, :enum] if name.nil?
        return [value, :in] unless allowed.include?(name)

        [name, nil]
      end

      private

      def after_declaration
        raise DeclarationError, "input #{name} takes no in option" if options.key?(:in)
        return if Array(options[:values]).any?

        raise DeclarationError, "input #{name} needs a non-empty values option"
      end

      def allowed
        @allowed ||= Array(options[:values]).map(&:to_sym)
      end
    end
  end
end
