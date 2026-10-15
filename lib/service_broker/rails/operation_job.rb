module ServiceBroker
  # Namespace of the job classes, one per operation. A worker that boots fresh
  # resolves the name through const_missing instead of a registry.
  module Jobs
    class << self
      # Builds, or returns, the job class that carries the name of one operation.
      def job_class_for(operation_name, parent)
        parts = operation_name.split('::')
        container = parts[0..-2].inject(self) { |level, part| namespace_in(level, part) }
        short_name = parts.last
        return container.const_get(short_name, false) if container.const_defined?(short_name, false)

        container.const_set(short_name, new_job_class(parent, operation_name))
      end

      # A worker that boots fresh asks for ServiceBroker::Jobs::<Operation> before
      # anything built it, so the name resolves here.
      def const_missing(name)
        const_set(name, missing_job_class(self, name))
      end

      def missing_job_class(container, name)
        prefix = container.name.to_s.delete_prefix('ServiceBroker::Jobs').delete_prefix('::')
        operation_name = [prefix, name].reject(&:empty?).join('::')
        new_job_class(ServiceBroker.config.job_parent_name.to_s.constantize, operation_name)
      end

      # The class answers a nested name too: a missing name cannot say whether it
      # is an operation or a namespace of operations.
      def new_job_class(parent, operation_name = nil)
        job_class = Class.new(parent) do
          include OperationJobBody
          extend NestedJobs
        end
        declare_unique(job_class, operation_name)
        job_class
      end

      private

      def declare_unique(job_class, operation_name)
        operation = operation_name&.safe_constantize
        options = operation.unique_options if operation.respond_to?(:unique_options)
        return unless options

        unless job_class.respond_to?(:unique)
          raise ConfigurationError, "#{operation_name} is unique but #{job_class.superclass} has no `unique`"
        end

        job_class.unique(options[:strategy], **{ lock_ttl: options[:ttl] }.compact)
      end

      def namespace_in(level, part)
        return level.const_get(part, false) if level.const_defined?(part, false)

        level.const_set(part, Module.new.tap { |mod| mod.singleton_class.include(NestedJobs) })
      end
    end
  end

  # Nested namespaces of job classes answer a missing name the same way.
  module NestedJobs
    def const_missing(name)
      const_set(name, Jobs.missing_job_class(self, name))
    end
  end

  # Runs one operation out of the queue and decides about a retry.
  module OperationJobBody
    def self.included(base)
      base.rescue_from(::ActiveJob::DeserializationError) do |error|
        ServiceBroker.config.error_reporter.call(error, operation: arguments.first.to_s)
        nil
      end
    end

    def perform(operation_name, inputs)
      cleaned = ServiceBroker.symbolize(inputs)
      self.arguments = [operation_name, cleaned.transform_keys(&:to_s)]

      operation_name.constantize.run_sync(**cleaned)
    rescue ServiceBroker::ValidationError
      nil
    rescue StandardError => e
      rule = ServiceBroker.config.retry_on[e.class.name]
      wait = e.respond_to?(:retry_after) ? e.retry_after : rule&.fetch(:wait, nil)
      raise e if wait.nil?

      limit = rule&.fetch(:attempts, nil) || ServiceBroker.config.max_retries
      raise e if executions >= limit

      retry_job(wait: wait)
      nil
    end
  end
end
