module ServiceBroker
  # One decision for a queued job: when it runs again, and which error reports of an attempt go out.
  module RetryPlan
    ATTEMPT_KEY = :service_broker_job_attempt

    def self.wait_for(error, executions)
      rule = ServiceBroker.config.retry_on[error.class.name]
      wait = error.respond_to?(:retry_after) ? error.retry_after : rule&.fetch(:wait, nil)
      return if wait.nil?

      limit = rule&.fetch(:attempts, nil) || ServiceBroker.config.max_retries
      return if executions >= limit

      wait
    end

    def self.attempt(executions)
      previous = Thread.current[ATTEMPT_KEY]
      held = Thread.current[ATTEMPT_KEY] = []
      begin
        answer = yield
      rescue StandardError => e
        job_operation = held.reverse.find { |error, _operation, _sending| error.equal?(e) }&.at(1)
        send_held(held, quiet?(e, job_operation, executions) ? e : nil)
        raise
      end
      send_held(held)
      answer
    ensure
      Thread.current[ATTEMPT_KEY] = previous
    end

    def self.hold(error, operation, sending)
      held = Thread.current[ATTEMPT_KEY]
      return sending.call if held.nil?

      held << [error, operation, sending]
    end

    def self.send_held(held, skipped = nil)
      held.each { |error, _operation, sending| sending.call unless error.equal?(skipped) }
    end

    def self.quiet?(error, operation, executions)
      return true unless wait_for(error, executions).nil?

      error.is_a?(ValidationError) && operation.respond_to?(:missing_record?) && operation.missing_record?
    end
    private_class_method :send_held, :quiet?
  end
end
