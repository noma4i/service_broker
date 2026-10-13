module ServiceBroker
  # Writes one line before and one line after a call when the log option is on.
  class Log
    def initialize(operation_class, inputs, enabled)
      @operation_class = operation_class
      @inputs = inputs
      @enabled = enabled ? true : false
    end

    def start
      return unless @enabled

      write("starts with #{ServiceBroker.argument_types(@inputs)}")
    end

    def finish(answer)
      return unless @enabled

      write("finishes with #{outcome_text(answer)}")
    end

    private

    def write(text)
      ServiceBroker.config.logger.call("[#{@operation_class.name}] #{text}")
    end

    def outcome_text(answer)
      case answer
      when Outcome then answer.success? ? 'success' : "errors #{answer.errors.symbolic}"
      when StandardError then answer.class.to_s
      else 'success'
      end
    end
  end
end
