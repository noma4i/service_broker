module ServiceBroker
  module Filters
    # Object input of a declared class.
    class Model < Base
      def self.default_options
        { nils: false, class: nil, new_records: false }
      end

      def filter(value)
        return nil_answer if value.nil?
        return [value, :empty] if value == ''
        return [value, :model] unless value.is_a?(options[:class])

        if !options[:new_records] && value.respond_to?(:new_record?) && value.new_record?
          return [value, :new_records]
        end

        [value, nil]
      end

      private

      def after_declaration
        klass = options[:class]
        raise DeclarationError, "input #{name} needs a class option" if klass.nil?
        return if klass.is_a?(::Class)

        raise DeclarationError, "input #{name} takes a class, not #{klass.class}"
      end
    end
  end
end
