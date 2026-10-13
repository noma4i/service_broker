module ServiceBroker
  module Filters
    # Polymorphic record input: the record, its global id or a type with an id.
    class Record < Base
      def self.default_options
        { nils: false, in: nil }
      end

      def filter(value)
        return nil_answer if value.nil?
        return [value, :empty] if value == ''

        case value
        when ::ActiveRecord::Base then from_object(value)
        when ::String then from_locator(value)
        when ::Hash then from_pair(value)
        else [value, :record]
        end
      end

      private

      def from_object(record)
        return [record, :in] unless allowed?(record.class)

        [record, nil]
      end

      def from_locator(text)
        locator = ::GlobalID.parse(text)
        return [text, :record] if locator.nil?

        klass = model_class_of(locator)
        return [text, :record] if klass.nil?
        return [text, :in] unless allowed?(klass)

        record = read(klass, locator.model_id)
        record.nil? ? [text, :not_found] : [record, nil]
      end

      def from_pair(pair)
        type = pair[:type] || pair['type']
        id = pair[:id] || pair['id']
        return [pair, :record] if type.nil? || id.nil?

        klass = resolve(type)
        return [pair, :record] if klass.nil?
        return [pair, :in] unless allowed?(klass)

        record = read(klass, id)
        record.nil? ? [pair, :not_found] : [record, nil]
      end

      def model_class_of(locator)
        locator.model_class
      rescue ::NameError
        nil
      end

      def resolve(type)
        klass = type.to_s.safe_constantize
        klass if klass.is_a?(::Class) && klass < ::ActiveRecord::Base
      end

      def read(klass, id)
        klass.find_by(id: id)
      end

      def allowed?(klass)
        return true if options[:in].nil?

        Array(options[:in]).any? { |allowed| klass <= allowed }
      end
    end
  end
end
