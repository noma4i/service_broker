class Probe::CaughtThrottling < ServiceBroker::Operation
  def execute
    Probe::Throttling.call
  rescue Probe::Throttled
    nil
  end
end
