class Probe::Throttling < ServiceBroker::Operation
  def execute
    raise Probe::Throttled
  end
end
