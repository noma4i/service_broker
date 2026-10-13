module ServiceBroker
  # Base of every application operation: declared inputs, one entry point, one execute.
  class Operation
    EXECUTION_OPTIONS = %i[safe soft async queue delay priority log].freeze
    EXECUTION_DEFAULTS = {
      safe: false, soft: false, async: false, queue: :default, delay: nil, priority: nil,
      log: false
    }.freeze

    class << self
      include Queueing
      include Reporting
      include OptionDeclarations
      include Composition::Declarations
      include Running

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@input_set, input_set.dup)
        subclass.instance_variable_set(:@execution_defaults, execution_defaults.dup)
        subclass.instance_variable_set(:@abstract_methods, abstract_methods.dup)
        subclass.input_set.owner = subclass
      end

      def singleton_method_added(name)
        super
        return unless name == :call && self != Operation

        raise DeclarationError, 'the call entry point belongs to ServiceBroker::Operation'
      end

      def method_added(name)
        super
        return unless name == :initialize && self != Operation

        raise DeclarationError, 'an operation declares no initialize: data comes from inputs'
      end

      def input_set
        @input_set ||= InputSet.new.tap { |set| set.owner = self }
      end

      def required(&)
        input_set.required(&)
      end

      def optional(&)
        input_set.optional(&)
      end

      def allow_unknown(flag = true)
        input_set.allow_unknown = flag
      end

      def requires_one_of(*names)
        input_set.requires_one_of(*names)
      end

      def defaults(**options)
        unknown = options.keys - EXECUTION_OPTIONS
        raise DeclarationError, "unknown execution options #{unknown.join(', ')}" if unknown.any?

        execution_defaults.merge!(options)
      end

      def execution_defaults
        @execution_defaults ||= EXECUTION_DEFAULTS.dup
      end

      def abstract_methods(*names)
        @abstract_methods ||= []
        @abstract_methods.concat(names.map(&:to_sym)) if names.any?
        @abstract_methods
      end

      def input_names
        input_set.names
      end

      def input_type(name)
        input_set.type_of(name)
      end

      def asyncable?
        true
      end

      def define_input_methods(name)
        define_method(name) { @inputs[name.to_s] }
        define_method("#{name}=") { |value| @inputs[name.to_s] = value }
        define_method("#{name}_present?") { @inputs.key?(name.to_s) }
      end

      # The entry point of application code.
      def call(**args, &)
        options = read_options(args)
        inputs = args.except(*EXECUTION_OPTIONS)

        return enqueue(inputs, options) if options[:async]

        perform(inputs, options, &)
      end

      def validate(**args)
        options = read_options(args)
        inputs = args.except(*EXECUTION_OPTIONS)

        perform(inputs, options.merge(soft: true, check_only: true))
      end

      def run_sync(**args, &)
        options = read_options(args)
        inputs = args.except(*EXECUTION_OPTIONS)

        perform(inputs, options.merge(async: false), &)
      end

      private

      def read_options(args)
        options = execution_defaults.dup
        EXECUTION_OPTIONS.each { |name| options[name] = args[name] if args.key?(name) }
        options
      end
    end

    include Composition::Steps

    def initialize(arguments = {})
      @raw_inputs = ServiceBroker.indifferent(arguments)
      checked, errors = self.class.input_set.check(arguments)
      @inputs = ServiceBroker.indifferent(checked)
      @errors = errors

      validate unless has_errors?
    end

    # Checks the inputs, runs execute and wraps the answer.
    def run(&)
      return outcome if has_errors?

      caught = catch(:service_broker_error) { return outcome(run_steps(&)) }
      @errors = caught
      outcome
    end

    def run!(&)
      answer = run(&)
      return answer.result if answer.success?

      raise ValidationError, answer.errors
    end

    def run_steps(&)
      run_before_steps
      result = execute(&)
      inside, = self.class.after_steps.partition(&:in_transaction)
      run_after_steps(inside, result)
      result
    end

    def outcome(result = nil)
      Outcome.new(
        success: !has_errors?,
        result: has_errors? ? nil : result,
        errors: @errors,
        inputs: @inputs,
        raw_inputs: @raw_inputs
      )
    end

    def report_context
      {}
    end

    def has_errors?
      !@errors.nil?
    end

    private

    attr_reader :inputs, :raw_inputs, :errors

    def validate; end

    def execute; end

    # Keeps one value for the length of this call.
    def memo(key, &block)
      @memo ||= {}
      return @memo[key] if @memo.key?(key)
      return nil unless block

      @memo[key] = block.call
    end

    def add_error(key, code, message = nil)
      @errors ||= Errors.new
      path = key.to_s.split('.')
      last = path.pop
      target = path.inject(@errors) { |level, part| level[part] ||= Errors.new }
      target[last] = ErrorAtom.new(last.to_sym, code, message: message)
      @errors
    end

    def merge_errors(other)
      return @errors if other.nil? || other.empty?

      @errors ||= Errors.new
      return @errors[:base] = other if other.is_a?(StructuredErrors)

      @errors.merge!(other)
    end

    def throw_error(code, text)
      errors = Errors.new
      errors[:error] = ErrorAtom.new(:error, code, message: text)

      throw :service_broker_error, errors
    end

    def throw_structured_error(fields)
      throw :service_broker_error, StructuredErrors.new(fields)
    end
  end

  # Sync-only base: a call with async is refused instead of queued.
  class SyncOperation < Operation
    def self.asyncable?
      false
    end
  end
end
