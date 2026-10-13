module ServiceBroker
  # Registry of input types available in declaration blocks.
  module Filters
    class << self
      def registry
        @registry ||= {}
      end

      def register(name, klass)
        key = name.to_sym
        raise DeclarationError, "input type #{key} is already registered" if registry.key?(key)

        registry[key] = klass
        define_declaration(key)
      end

      def replace(name, klass)
        registry[name.to_sym] = klass
        define_declaration(name.to_sym)
      end

      def unregister(name)
        key = name.to_sym
        registry.delete(key)
        Declarations.send(:remove_method, key) if Declarations.method_defined?(key)
      end

      def lookup(name)
        registry[name.to_sym]
      end

      def fetch(name)
        registry[name.to_sym] || raise(DeclarationError, "unknown input type #{name}")
      end

      def names
        registry.keys
      end

      private

      # Every registered type becomes one declaration method of this module.
      def define_declaration(key)
        return if Declarations.method_defined?(key)

        Declarations.define_method(key) do |input_name = nil, **options, &block|
          declare_input(key, input_name, options, block)
        end
      end
    end

    # Declaration methods of every registered type. Included by declaration readers.
    module Declarations
    end
  end
end
