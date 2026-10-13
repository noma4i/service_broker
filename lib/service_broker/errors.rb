module ServiceBroker
  class Error < StandardError
  end

  class DeclarationError < Error
  end

  class ConfigurationError < Error
  end

  class AsyncForbidden < Error
  end

  class SerializationError < Error
  end

  # Raised inside a safe call to roll the transaction back after a failed answer.
  class RollbackSignal < Error
  end

  class ValidationError < Error
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super(errors.message_list.join('. '))
    end
  end

  # One failure of one input: its key, its code and the text a reader sees.
  class ErrorAtom
    attr_reader :key, :index

    def initialize(key, code, message: nil, index: nil)
      raise ArgumentError, 'error code must be a Symbol' unless code.is_a?(::Symbol)

      @key = key
      @code = code
      @message = message
      @index = index
    end

    def symbolic
      @code
    end

    def message
      @message ||= ServiceBroker.config.message_builder.call(@key, @code, index: @index)
    end

    def message_list
      [message]
    end
  end

  # Failures of array elements: index to atom, with nil in the valid slots.
  class ErrorList
    include Enumerable

    def initialize(slots)
      @slots = slots
    end

    def each(&)
      @slots.each(&)
    end

    def [](index)
      @slots[index]
    end

    def size
      @slots.size
    end

    def symbolic
      @slots.map { |slot| slot&.symbolic }
    end

    def message
      @slots.map { |slot| slot&.message }
    end

    def message_list
      @slots.compact.flat_map(&:message_list)
    end
  end

  # Failures of one call: input name to atom, to nested Errors or to ErrorList.
  class Errors
    include Enumerable

    def initialize(pairs = {})
      @pairs = {}
      pairs.each { |key, value| self[key] = value }
    end

    def []=(key, value)
      @pairs[key.to_s] = value
    end

    def [](key)
      @pairs[key.to_s]
    end

    def key?(key)
      @pairs.key?(key.to_s)
    end

    def keys
      @pairs.keys
    end

    def each(&)
      @pairs.each(&)
    end

    def any?(...)
      @pairs.any?(...)
    end

    def empty?
      @pairs.empty?
    end

    def merge!(other)
      other.each { |key, value| self[key] = value }
      self
    end

    def symbolic
      @pairs.transform_values(&:symbolic)
    end

    def message
      @pairs.transform_values(&:message)
    end

    def message_list
      @pairs.values.flat_map(&:message_list)
    end
  end

  # Failure with its own fields, raised by throw_structured_error.
  class StructuredErrors < Errors
    def initialize(fields)
      super()
      @fields = {}
      fields.each { |key, value| @fields[key.to_s] = value }
      @messages = Array(@fields['message']).compact
    end

    def [](key)
      return @fields[key.to_s] if @fields.key?(key.to_s)

      super
    end

    def keys
      @fields.keys
    end

    def any?(...)
      return true if @fields.any?

      @fields.any?(...)
    end

    def empty?
      @fields.empty?
    end

    def symbolic
      @fields
    end

    def message
      @fields
    end

    def message_list
      @messages
    end
  end
end
