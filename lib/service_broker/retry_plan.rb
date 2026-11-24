module ServiceBroker
  # Decides whether a queued job runs again after an error, and when. The job and the error report
  # read the same answer: an error the job repeats is not reported until the last attempt.
  module RetryPlan
    ATTEMPT_KEY = :service_broker_job_attempt

    # Seconds until the next run, or nil when the job stops here.
    def self.wait_for(error, executions)
      rule = ServiceBroker.config.retry_on[error.class.name]
      wait = error.respond_to?(:retry_after) ? error.retry_after : rule&.fetch(:wait, nil)
      return if wait.nil?

      limit = rule&.fetch(:attempts, nil) || ServiceBroker.config.max_retries
      return if executions >= limit

      wait
    end

    # Runs the block as attempt number `executions` of a queued job.
    def self.attempt(executions)
      previous = Thread.current[ATTEMPT_KEY]
      Thread.current[ATTEMPT_KEY] = executions
      yield
    ensure
      Thread.current[ATTEMPT_KEY] = previous
    end

    # True inside a queued job that will run again after this error.
    def self.follows?(error)
      executions = Thread.current[ATTEMPT_KEY]

      !executions.nil? && !wait_for(error, executions).nil?
    end
  end
end
