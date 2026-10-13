module ServiceBroker
  module Filters
    # Readable input with a known size.
    class File < Base
      METHODS = %i[read size].freeze
      UPLOAD_METHODS = %i[original_filename content_type].freeze

      def self.default_options
        { nils: false, upload: false, size: nil }
      end

      def filter(value)
        return nil_answer if value.nil?
        return [value, :empty] if value == ''

        needed = options[:upload] ? METHODS + UPLOAD_METHODS : METHODS
        return [value, :file] unless needed.all? { |method| value.respond_to?(method) }
        return [value, :size] if options[:size].is_a?(::Integer) && value.size > options[:size]

        [value, nil]
      end
    end
  end
end
