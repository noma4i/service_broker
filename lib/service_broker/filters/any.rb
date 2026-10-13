module ServiceBroker
  module Filters
    # Input of any class: the only rule is that it is there.
    class Any < Base
      def self.default_options
        { nils: false }
      end

      def filter(value)
        return nil_answer if value.nil?

        [value, nil]
      end
    end
  end
end
