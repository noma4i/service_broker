module ServiceBroker
  module Filters
    # Record input: takes the record itself or its identifier.
    class Finder < Base
      def self.default_options
        { nils: false, model: nil, unscoped: false, preload: nil, new_records: false }
      end

      def filter(value)
        return nil_answer if value.nil?
        return [value, :empty] if value == ''

        record = resolve(value)
        return [value, :not_found] if record.nil?
        return [value, :model] unless record.is_a?(options[:model])
        return [value, :new_records] if !options[:new_records] && record.new_record?

        [record, nil]
      end

      private

      def after_declaration
        model = options[:model]
        raise DeclarationError, "input #{name} needs a model option" if model.nil?
        return if model.is_a?(::Class)

        raise DeclarationError, "input #{name} takes a model class, not #{model.class}"
      end

      # A record, a global id string or a plain identifier all name one row.
      def resolve(value)
        return value if value.is_a?(::ActiveRecord::Base)
        return from_locator(value) if value.is_a?(::String) && value.start_with?('gid://')

        read(value)
      end

      def from_locator(text)
        locator = ::GlobalID.parse(text)
        return nil if locator.nil?

        klass = model_class_of(locator)
        return nil if klass.nil?
        return nil unless klass <= options[:model]

        read(locator.model_id)
      end

      def model_class_of(locator)
        locator.model_class
      rescue ::NameError
        nil
      end

      def read(identifier)
        scope = options[:unscoped] ? options[:model].unscoped : options[:model].all
        scope = scope.preload(options[:preload]) if options[:preload]
        scope.find_by(id: identifier)
      end
    end
  end
end
