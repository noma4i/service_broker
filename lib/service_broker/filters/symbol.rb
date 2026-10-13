module ServiceBroker
  module Filters
    # Name input: accepts a Symbol or a non-blank String.
    class Symbol < Base
      def self.default_options
        { nils: false, empty_is_nil: false, in: nil }
      end

      def filter(value)
        value = nil if options[:empty_is_nil] && value == ''
        return nil_answer if value.nil?
        return [value, :empty] if value == ''

        name = case value
               when ::Symbol then value
               when ::String then value.to_sym
               end
        return [value, :symbol] if name.nil?
        return [name, :in] if options[:in] && !options[:in].include?(name)

        [name, nil]
      end
    end
  end
end
