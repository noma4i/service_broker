module ServiceBroker
  module Filters
    # Record input addressed by a global id.
    class Gid < Base
      def self.default_options
        { nils: false, in: nil }
      end

      def filter(value)
        return nil_answer if value.nil?
        return [value, :empty] if value == ''

        locator = ::GlobalID.parse(value)
        return [value, :gid] if locator.nil?

        klass = model_class_of(locator)
        return [value, :gid] if klass.nil?
        return [value, :in] if options[:in] && !options[:in].include?(klass)

        record = locate(locator)
        record.nil? ? [value, :not_found] : [record, nil]
      end

      private

      def model_class_of(locator)
        locator.model_class
      rescue ::NameError
        nil
      end

      def locate(locator)
        locator.find
      rescue ::ActiveRecord::RecordNotFound, ::NameError
        nil
      end
    end
  end
end
