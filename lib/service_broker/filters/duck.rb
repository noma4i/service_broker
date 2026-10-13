module ServiceBroker
  module Filters
    # Input checked by the methods it has to answer.
    class Duck < Base
      def self.default_options
        { nils: false, methods: nil }
      end

      def filter(value)
        return nil_answer if value.nil?

        answers = Array(options[:methods]).all? { |method| value.respond_to?(method) }
        answers ? [value, nil] : [value, :duck]
      end

      private

      def after_declaration
        return if Array(options[:methods]).any?

        raise DeclarationError, "input #{name} needs a non-empty methods option"
      end
    end
  end
end
