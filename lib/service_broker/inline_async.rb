module ServiceBroker
  # Runs the operation at once instead of queueing it. Used by application tests.
  class InlineAsync
    def enqueue(operation_class, inputs, **)
      operation_class.run_sync(**inputs)

      "inline:#{operation_class.name}"
    end

    def job_name_for(operation_class)
      operation_class.name
    end
  end
end
