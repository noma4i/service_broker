module ServiceBroker
  # Puts one call of an operation into the configured runner.
  module Queueing
    def enqueue(inputs, options)
      raise AsyncForbidden, "#{name} is not asyncable" unless asyncable?

      payload = inputs.merge(safe: options[:safe], soft: options[:soft])
      job_id = ServiceBroker.config.async_runner.enqueue(
        self, payload, queue: options[:queue], delay: options[:delay], priority: options[:priority]
      )
      Events.queued(self, options, inputs, job_id)

      job_id
    end
  end
end
