module ServiceBroker
  # One decision for a queued job and its error report: when the job runs again, and which error of
  # an attempt stays out of the report (the job repeats it, or the record of the job is gone).
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
      Thread.current[ATTEMPT_KEY] = executions
      yield
    ensure
      Thread.current[ATTEMPT_KEY] = previous
    end

    def self.quiet?(error)
      executions = Thread.current[ATTEMPT_KEY]
      return false if executions.nil?

      !wait_for(error, executions).nil? || record_gone?(error)
    end

    def self.record_gone?(error)
      return false unless error.is_a?(ValidationError) && error.errors.is_a?(Errors)

      codes = error.errors.symbolic.values

      codes.any? && codes.all?(:not_found)
    end
  end
end
