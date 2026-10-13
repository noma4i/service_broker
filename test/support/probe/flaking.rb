class Probe::Flaking < ServiceBroker::Operation
  def execute
    raise Probe::Flaky
  end
end
