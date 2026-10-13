class Probe::Rejecting < ServiceBroker::Operation
  required do
    string :name
  end

  def execute
    throw_error(:not_allowed, "Name '#{name}' is not allowed")
  end
end
