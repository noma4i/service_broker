module ServiceBroker
  # Sends one event per call and per queueing to the configured listener.
  module Events
    CALL = 'service_broker.call'.freeze
    ENQUEUE = 'service_broker.enqueue'.freeze

    class << self
      def call_finished(operation_class, options, inputs, answer, duration_ms)
        publish(CALL, {
                  operation: operation_class.name,
                  options: options,
                  argument_types: ServiceBroker.argument_types(inputs),
                  success: answer.is_a?(StandardError) ? false : success?(answer),
                  error_class: error_class_of(answer),
                  duration_ms: duration_ms
                })
      end

      def queued(operation_class, options, inputs, job_id)
        publish(ENQUEUE, {
                  operation: operation_class.name,
                  argument_types: ServiceBroker.argument_types(inputs),
                  queue: options[:queue],
                  delay: options[:delay],
                  priority: options[:priority],
                  job_id: job_id
                })
      end

      private

      def success?(answer)
        answer.is_a?(Outcome) ? answer.success? : true
      end

      def error_class_of(answer)
        return answer.class.name if answer.is_a?(StandardError)
        return answer.exception.class.name if answer.is_a?(Outcome) && answer.exception

        nil
      end

      def publish(name, payload)
        listener = ServiceBroker.config.instrumenter
        return if listener.nil?

        listener.call(name, payload)
      rescue StandardError => e
        ServiceBroker.config.logger.call("[#{name}] listener failed with #{e.class}: #{e.message}")
      end
    end
  end
end
