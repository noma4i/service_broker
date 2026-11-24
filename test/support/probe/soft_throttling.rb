class Probe::SoftThrottling < ServiceBroker::Operation
  def execute
    Probe::Throttling.call(soft: true)
    nil
  end
end
