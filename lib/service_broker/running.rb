module ServiceBroker
  # Steps of one call on the class side: options, transaction, logging and the answer.
  module Running
    private

    def perform(inputs, options, &)
      state = {}
      unless options[:safe]
        answer = watched(inputs, options) { run_checked(inputs, options, state, &) }
        committed_after_steps(state)
        return answer
      end

      answer = nil
      watched(inputs, options) do
        ServiceBroker.transaction do
          answer = run_checked(inputs, options, state, &)
          raise RollbackSignal if state[:failed]
        end

        answer
      end
      committed_after_steps(state)

      answer
    end

    def run_checked(inputs, options, state = {}, &)
      logger = Log.new(self, inputs, options[:log])
      check_abstract_methods!
      logger.start

      operation = new(inputs)
      outcome = options[:check_only] ? operation.outcome : operation.run(&)
      logger.finish(outcome)
      state[:failed] = !outcome.success?
      state[:operation] = operation
      state[:result] = outcome.result

      answer(outcome, options)
    rescue StandardError => e
      raise if ServiceBroker.config.pass_through_errors.any? { |klass| e.is_a?(klass) }

      logger.finish(e)
      report(e, inputs, operation)
      state[:failed] = true
      raise e unless options[:soft]

      failed_outcome(e, inputs)
    end

    def check_abstract_methods!
      missing = abstract_methods.reject do |method|
        method_defined?(method) || private_method_defined?(method)
      end
      return if missing.empty?

      raise DeclarationError, "#{name} does not define #{missing.join(', ')}"
    end
  end
end
