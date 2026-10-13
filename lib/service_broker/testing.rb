require 'service_broker'

module ServiceBroker
  # Helpers for application tests: records queued operations or runs them at once.
  module Testing
    QueuedOperation = Struct.new(:operation_class, :arguments, :queue, :delay, :priority, :job_id)

    # Records every queued operation instead of touching a real queue.
    class RecordingAsync
      attr_reader :queued

      def initialize
        @queued = []
      end

      def enqueue(operation_class, inputs, queue:, delay:, priority:)
        job_id = "recorded:#{@queued.size}"
        @queued << QueuedOperation.new(operation_class, ServiceBroker.indifferent(inputs), queue,
                                       delay, priority, job_id)

        job_id
      end

      def job_name_for(operation_class)
        operation_class.name
      end
    end

    def with_queued_operations
      recorder = RecordingAsync.new
      previous = ServiceBroker.config.async_runner_or_nil
      ServiceBroker.config.async_runner = recorder
      @service_broker_recorder = recorder
      yield

      recorder.queued
    ensure
      restore_runner(previous)
      @service_broker_recorder = nil
    end

    def with_inline_operations
      previous = ServiceBroker.config.async_runner_or_nil
      ServiceBroker.config.async_runner = InlineAsync.new
      yield
    ensure
      restore_runner(previous)
    end

    def assert_operation_queued(operation_class, **arguments)
      recorded = queued_operations
      found = recorded.select { |item| item.operation_class == operation_class }
      matching = found.select do |item|
        arguments.all? { |name, value| item.arguments[name] == value }
      end

      assert !matching.empty?,
             "expected #{operation_class} queued with #{arguments.inspect}, " \
             "got #{recorded.map { |item| [item.operation_class.to_s, item.arguments.to_h] }.inspect}"

      matching.first
    end

    private

    # Puts back the runner that was set before the block, even when none was.
    def restore_runner(previous)
      if previous.nil?
        ServiceBroker.config.instance_variable_set(:@async_runner, nil)
      else
        ServiceBroker.config.async_runner = previous
      end
    end

    public

    def queued_operations
      recorder = @service_broker_recorder
      return recorder.queued if recorder

      raise ConfigurationError, 'read queued operations inside with_queued_operations'
    end
  end
end
