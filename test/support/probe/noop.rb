class Probe::Noop < ServiceBroker::Operation
  required do
    string :name
  end

  def execute
    name
  end
end
