module ServiceBroker
  # Steps of one operation: the declarations of the class and the call of one step.
  module Composition
    Step = Struct.new(:operation_class, :mapping, :async, :condition, :in_transaction) do
      def queued? = async ? true : false

      def allowed?(result)
        return true if condition.nil?

        condition.call(result) ? true : false
      end
    end

    # Declarations of one operation class.
    module Declarations
      FLAGS = %i[async if in_transaction].freeze

      def before(operation_class, **mapping)
        own_before_steps << build_step(operation_class, mapping)
      end

      def after(operation_class, **mapping)
        own_after_steps << build_step(operation_class, mapping)
      end

      def before_steps
        inherited_steps(:own_before_steps)
      end

      def after_steps
        inherited_steps(:own_after_steps)
      end

      private

      def own_before_steps
        @own_before_steps ||= []
      end

      def own_after_steps
        @own_after_steps ||= []
      end

      def inherited_steps(reader)
        own = send(reader)
        return own unless superclass.respond_to?(reader, true)

        superclass.send(reader.to_s.sub('own_', '').to_sym) + own
      end

      # Runs the after steps of a successful call once its transaction is closed.
      def committed_after_steps(state)
        operation = state[:operation]
        return if operation.nil? || state[:failed]

        _, outside = after_steps.partition(&:in_transaction)
        operation.send(:run_after_steps, outside, state[:result])
      end

      def build_step(operation_class, mapping)
        check_step_class(operation_class)
        condition = mapping[:if]
        check_step_condition(condition)

        Step.new(operation_class, mapping.except(*FLAGS), mapping[:async], condition,
                 mapping[:in_transaction])
      end

      def check_step_condition(condition)
        return if condition.nil? || condition.respond_to?(:call)

        raise DeclarationError, 'the if of a step needs an object that answers to call'
      end

      def check_step_class(operation_class)
        return if operation_class.is_a?(Class) && operation_class <= Operation

        raise DeclarationError, "#{operation_class} is not a ServiceBroker::Operation"
      end
    end

    # Runs one declared step of one operation instance.
    module Steps
      private

      def run_before_steps
        self.class.before_steps.each do |step|
          arguments = step_arguments(step, self)
          call_step(step.operation_class, arguments, nil)
        end
      end

      def run_after_steps(steps, result)
        steps.each do |step|
          next unless step.allowed?(result)

          arguments = step_arguments(step, result)
          next ServiceBroker.enqueue_step(step.operation_class, arguments) if step.queued?

          report_failed_after(step, step.operation_class.call(**arguments, soft: true))
        end
      end

      def report_failed_after(step, outcome)
        return if outcome.success?

        error = outcome.exception || ValidationError.new(outcome.errors)
        step.operation_class.send(:report, error, outcome.raw_inputs)
        name = step.operation_class.name
        ServiceBroker.config.logger.call("[#{self.class.name}] after step #{name} failed")
      end

      def step(operation_class, as: nil, **arguments)
        call_step(operation_class, arguments, as)
      end

      def call_step(operation_class, arguments, key)
        outcome = ServiceBroker.with_step_depth { operation_class.call(**arguments, soft: true) }
        return outcome.result if outcome.success?

        fail_with_step_errors(outcome.errors, key)
      end

      def fail_with_step_errors(step_errors, key)
        if key
          @errors ||= Errors.new
          @errors[key] = step_errors
        else
          merge_errors(step_errors)
        end

        throw :service_broker_error, @errors
      end

      def step_arguments(step, context)
        step.mapping.transform_values { |value| step_value(value, context) }
      end

      def step_value(value, context)
        return inputs[value] if value.is_a?(::Symbol) && self.class.input_names.include?(value)
        return value.call(context) if value.respond_to?(:call)

        value
      end
    end
  end

  class << self
    # Counts the depth of nested steps of one call in this thread.
    def with_step_depth
      depth = step_depth + 1
      raise StepDepthError, "steps go deeper than #{config.max_step_depth}" if depth > config.max_step_depth

      Thread.current[:service_broker_step_depth] = depth
      yield
    ensure
      Thread.current[:service_broker_step_depth] = depth > 1 ? depth - 1 : nil
    end

    def step_depth
      Thread.current[:service_broker_step_depth] || 0
    end

    def enqueue_step(operation_class, arguments)
      operation_class.call(**arguments, async: true)
    end
  end
end
