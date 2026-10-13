module ServiceBroker
  module Filters
    # Nested input with declared keys and types.
    class Hash < Base
      def self.default_options
        { nils: false, of: nil }
      end

      def filter(value)
        return nil_answer if value.nil?
        return [value, :empty] if value == ''
        return [value, :hash] unless value.respond_to?(:to_hash)

        checked, errors = set.check(symbolize(value.to_hash))
        errors ? [value, errors] : [ServiceBroker.indifferent(checked), nil]
      end

      private

      def after_declaration
        raise DeclarationError, "input #{name} takes a block or of:, not both" if block && options[:of]
        unless block || options[:of]
          raise DeclarationError,
                "input #{name} needs a block with its keys or of:"
        end

        @set = InputSet.new
        element = options[:of]
        return @set.optional { send(element, :*) } unless block

        @set.required(&block)
      end

      attr_reader :set

      def symbolize(hash)
        hash.to_h { |key, item| [key.to_sym, item] }
      end
    end
  end
end
