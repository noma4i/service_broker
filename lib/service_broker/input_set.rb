module ServiceBroker
  # Holds the declared inputs of one operation class and checks one set of arguments.
  class InputSet
    include Filters::Declarations

    STAR = :*
    RESERVED = %i[
      run run! run_sync call execute initialize validate inputs raw_inputs errors has_errors?
      outcome add_error merge_errors throw_error throw_structured_error memo report_context safe
      soft async queue delay priority log class clone dup freeze frozen? hash inspect instance_variables
      method methods nil? object_id public_send respond_to? send tap then to_s
    ].freeze

    attr_reader :required_inputs, :optional_inputs, :rules

    def initialize
      @required_inputs = {}
      @optional_inputs = {}
      @own_names = {}
      @rules = []
      @current = :required
      @owner = nil
      @allow_unknown = false
    end

    def initialize_copy(source)
      super
      @required_inputs = source.required_inputs.dup
      @optional_inputs = source.optional_inputs.dup
      @rules = source.rules.dup
      @own_names = {}
    end

    # Declares that exactly one input of the list has to be present.
    def requires_one_of(*names)
      names = names.map(&:to_sym)
      raise DeclarationError, 'requires_one_of needs 2 or more input names' if names.size < 2

      unknown = names.reject { |name| @required_inputs.key?(name) || @optional_inputs.key?(name) }
      raise DeclarationError, "requires_one_of names unknown inputs #{unknown.join(', ')}" if unknown.any?

      @rules << names
    end

    attr_writer :owner

    def allow_unknown=(flag)
      @allow_unknown = flag ? true : false
    end

    def allow_unknown?
      @allow_unknown
    end

    def required(&)
      read(:required, &)
    end

    def optional(&)
      read(:optional, &)
    end

    def names
      (@required_inputs.keys + @optional_inputs.keys)
    end

    def type_of(name)
      filter = @required_inputs[name.to_sym] || @optional_inputs[name.to_sym]
      return nil unless filter

      Filters.registry.key(filter.class) || Filters.registry.key(filter.class.superclass)
    end

    # Any name that is not a registered type lands here through method_missing.
    def method_missing(type, *, **, &)
      raise DeclarationError, "unknown input type #{type}"
    end

    def respond_to_missing?(type, include_private = false)
      !Filters.lookup(type).nil? || super
    end

    def declare_input(type, input_name, options, block)
      name = check_name!(type, input_name)
      filter = Filters.fetch(type).new(name, options, &block)
      check_placement!(name, filter)
      store(name, filter)
      @owner&.define_input_methods(name) unless name == STAR
      filter
    end

    # Returns [checked inputs, errors or nil].
    def check(arguments)
      checked = {}
      errors = Errors.new
      remaining = arguments.keys.map(&:to_sym)

      @required_inputs.each do |name, filter|
        remaining -= check_one(name, filter, true, arguments, checked, errors)
      end
      @optional_inputs.each do |name, filter|
        remaining -= check_one(name, filter, false, arguments, checked, errors)
      end

      check_remaining(remaining, arguments, checked, errors)
      check_rules(checked, errors) unless errors.any?

      errors.any? ? [checked, errors] : [checked, nil]
    end

    private

    def read(section, &)
      previous = @current
      @current = section
      instance_eval(&)
      @current = previous
      self
    end

    def store(name, filter)
      target = @current == :required ? @required_inputs : @optional_inputs
      other = @current == :required ? @optional_inputs : @required_inputs
      other.delete(name)
      target[name] = filter
    end

    def check_name!(type, input_name)
      raise DeclarationError, "input of type #{type} needs a name" if input_name.nil?

      name = input_name.to_sym
      if RESERVED.include?(name)
        raise DeclarationError, "input name #{name} is reserved by the operation itself"
      end
      raise DeclarationError, "input #{name} is declared twice" if @own_names.key?(name)

      @own_names[name] = true
      name
    end

    def check_placement!(name, filter)
      if name == STAR
        if @required_inputs.key?(STAR) || @optional_inputs.key?(STAR)
          raise DeclarationError, 'the * input is declared twice'
        end
        raise DeclarationError, 'the * input takes no error_key option' if filter.options.key?(:error_key)
      end
      return unless @current == :required

      discards = filter.options.keys & %i[discard_nils discard_empty discard_invalid]
      return if discards.empty?

      raise DeclarationError, "input #{name} is required and takes no #{discards.join(', ')}"
    end

    def check_one(name, filter, is_required, arguments, checked, errors)
      return [] if name == STAR

      key = arguments.key?(name) ? name : name.to_s
      unless arguments.key?(key)
        fill_default(name, filter, is_required, checked, errors)
        return []
      end

      value, code = filter.filter(arguments[key])
      value, code = filter.transform(value) if code.nil?

      if code.nil?
        checked[name.to_s] = value
      elsif !is_required && discard?(filter, code)
        fill_default(name, filter, false, checked, errors)
      else
        errors[filter.error_key] = atom(filter.error_key, code)
      end

      [name]
    end

    def fill_default(name, filter, is_required, checked, errors)
      return checked[name.to_s] = filter.default if filter.default?
      return unless is_required

      errors[filter.error_key] = ErrorAtom.new(filter.error_key, :required)
    end

    def discard?(filter, code)
      return true if filter.discard_invalid?
      return true if code == :empty && filter.discard_empty?
      return true if code == :nils && filter.discard_nils?

      false
    end

    def check_remaining(remaining, arguments, checked, errors)
      star = @required_inputs[STAR] || @optional_inputs[STAR]

      remaining.each do |name|
        key = arguments.key?(name) ? name : name.to_s

        if star
          value, code = star.filter(arguments[key])
          value, code = star.transform(value) if code.nil?
          code.nil? ? checked[name.to_s] = value : errors[name] = atom(name, code)
        elsif !allow_unknown?
          errors[name] = ErrorAtom.new(name, :unknown_input)
        end
      end
    end

    def atom(key, code)
      code.is_a?(::Symbol) ? ErrorAtom.new(key, code) : code
    end

    def check_rules(checked, errors)
      @rules.each do |names|
        present = names.count { |name| checked.key?(name.to_s) }
        next if present == 1

        errors[:base] = ErrorAtom.new(:base, :requires_one_of,
                                      message: "Exactly one of #{names.join(', ')} is required")
      end
    end
  end
end
