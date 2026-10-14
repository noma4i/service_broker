module ServiceBroker
  # Puts an operation into ActiveJob and names the job after that operation.
  class ActiveJobAsync
    def initialize
      @classes = {}
      @lock = Mutex.new
    end

    def enqueue(operation_class, inputs, queue:, delay:, priority:)
      payload = serializable(operation_class, inputs)
      options = { queue: queue, priority: priority, wait: delay }.compact
      job = job_class_for(operation_class).set(**options)
                                          .perform_later(operation_class.name, payload)
      return unless job

      job.job_id
    end

    def job_name_for(operation_class)
      job_class_for(operation_class).name
    end

    def job_class_for(operation_class)
      @lock.synchronize do
        @classes[operation_class.name] ||= build_job_class(operation_class)
      end
    end

    private

    def serializable(operation_class, inputs)
      payload = inputs.to_h { |key, value| [key.to_s, value] }
      ActiveJob::Arguments.serialize([payload])
      payload
    rescue ActiveJob::SerializationError => e
      raise SerializationError, "#{operation_class.name} cannot queue its inputs: #{e.message}"
    end

    def build_job_class(operation_class)
      Jobs.job_class_for(operation_class.name, parent_class)
    end

    def parent_class
      ServiceBroker.config.job_parent_name.constantize
    end
  end
end
