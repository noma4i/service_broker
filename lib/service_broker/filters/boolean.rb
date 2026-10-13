module ServiceBroker
  module Filters
    # Two-value input: accepts true, false, 1, 0 and their 4 text forms.
    class Boolean < Base
      TEXTS = { 'true' => true, 'false' => false, '1' => true, '0' => false }.freeze

      def self.default_options
        { nils: false, empty_is_nil: false }
      end

      def filter(value)
        value = nil if options[:empty_is_nil] && value == ''
        return nil_answer if value.nil?
        return [value, :empty] if value == ''
        return [value, nil] if [true, false].include?(value)

        text = text_form(value)
        return [value, :boolean] if text.nil?

        answer = TEXTS[text]
        answer.nil? ? [value, :boolean] : [answer, nil]
      end

      private

      def text_form(value)
        return value.to_s if value.is_a?(::Integer) && [0, 1].include?(value)
        return value.strip.downcase if value.is_a?(::String)

        nil
      end
    end
  end
end
