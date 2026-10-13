module ServiceBroker
  # Sends the events of one call and reports its exception.
  module Reporting
    # Runs the body, then sends one event about this call.
    def watched(inputs, options)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      answer = yield
      Events.call_finished(self, options, inputs, answer, elapsed_ms(started))

      answer
    rescue StandardError => e
      Events.call_finished(self, options, inputs, e, elapsed_ms(started))
      raise
    end

    def elapsed_ms(started)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(3)
    end

    # Turns one outcome into the answer the caller asked for.
    def answer(outcome, options)
      return outcome if options[:soft]
      raise ValidationError, outcome.errors unless outcome.success?

      outcome.result
    end

    def failed_outcome(error, inputs)
      errors = Errors.new
      errors[:base] = ErrorAtom.new(:base, :exception, message: ServiceBroker.exception_text(error))
      Outcome.new(success: false, result: nil, errors: errors, exception: error,
                  inputs: ServiceBroker.indifferent({}), raw_inputs: ServiceBroker.indifferent(inputs))
    end

    def report(error, inputs, operation = nil)
      config = ServiceBroker.config
      allowed = config.error_dedup.call(context: name, error_class: error.class.name)
      unless allowed
        config.logger.call("[#{name}] repeated #{error.class}: #{error.message}")
        return
      end

      context = { operation: name, argument_types: ServiceBroker.argument_types(inputs) }
      config.error_reporter.call(error, **context, **own_context(operation))
    rescue StandardError => e
      config.logger.call("[#{name}] error reporting failed with #{e.class}: #{e.message}")
    end

    # Reads the report_context of the operation when it declares one.
    def own_context(operation)
      return {} unless operation.respond_to?(:report_context, true)

      own = operation.send(:report_context)
      own.is_a?(::Hash) ? own.transform_keys(&:to_sym) : {}
    rescue StandardError => e
      ServiceBroker.config.logger.call("[#{name}] report_context failed with #{e.class}")
      {}
    end
  end
end
