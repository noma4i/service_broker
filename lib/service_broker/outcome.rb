module ServiceBroker
  # Answer of a checked and executed operation.
  class Outcome
    attr_reader :result, :errors, :inputs, :raw_inputs, :exception

    def initialize(success:, result:, errors:, inputs:, raw_inputs:, exception: nil)
      @success = success
      @result = result
      @errors = errors
      @inputs = inputs
      @raw_inputs = raw_inputs
      @exception = exception
    end

    def success?
      @success
    end
  end
end
