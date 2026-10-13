module ServiceBroker
  module Filters
    # List input with one declared element type.
    class Array < Base
      OWN_OPTIONS = %i[nils class min_length max_length of].freeze

      def self.default_options
        { nils: false, class: nil, min_length: nil, max_length: nil, of: nil }
      end

      def filter(value)
        return nil_answer if value.nil?
        return [value, :empty] if value == ''
        return [value, :array] unless value.is_a?(::Array)

        bound = bound_error(value)
        return [value, bound] if bound

        check_elements(value)
      end

      private

      def after_declaration
        check_element_declaration!
        @element = build_element
      end

      def check_element_declaration!
        ways = [options[:class], options[:of], block].compact.size
        return if ways == 1

        raise DeclarationError,
              "input #{name} needs exactly one element type: a block, of: or class:"
      end

      def build_element
        return element_from_block if block
        return nil unless options[:of]

        Filters.fetch(options[:of]).new(name, element_options)
      end

      def element_from_block
        element = ElementSet.new(name, &block).filter_object
        raise DeclarationError, "the block of input #{name} declares no element type" if element.nil?

        element
      end

      # Options that do not belong to the array itself are the element's own.
      def element_options
        options.reject { |key, _| OWN_OPTIONS.include?(key) || key == :transform }
      end

      def bound_error(value)
        return :min_length if options[:min_length] && value.length < options[:min_length]
        return :max_length if options[:max_length] && value.length > options[:max_length]

        nil
      end

      def check_elements(value)
        kept = []
        slots = []
        failed = false

        value.each_with_index do |element, index|
          checked, code = check_one(element)

          if code.nil?
            kept << checked
            slots << nil
          elsif discard_element?
            next
          else
            failed = true
            kept << element
            slots << atom_for(code, index)
          end
        end

        failed ? [value, ErrorList.new(slots)] : [kept, nil]
      end

      def check_one(element)
        unless @element
          return element.is_a?(options[:class]) ? [element, nil] : [element, :class]
        end

        value, code = @element.filter(element)
        code.nil? ? @element.transform(value) : [value, code]
      end

      def discard_element?
        @element&.discard_invalid?
      end

      def atom_for(code, index)
        return code unless code.is_a?(::Symbol)

        ErrorAtom.new(name, code, index: index)
      end
    end

    # Reads the single element declaration of an array block.
    class ElementSet
      include Declarations

      attr_reader :filter_object

      def initialize(name, &)
        @name = name
        @filter_object = nil
        instance_eval(&)
      end

      def declare_input(type, _input_name, options, block)
        @filter_object = Filters.fetch(type).new(@name, options, &block)
      end

      def method_missing(type, *, **, &)
        raise DeclarationError, "unknown input type #{type}"
      end

      def respond_to_missing?(type, include_private = false)
        !Filters.lookup(type).nil? || super
      end
    end
  end
end
