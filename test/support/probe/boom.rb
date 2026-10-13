class Probe::Boom < ServiceBroker::Operation
  optional do
    string :name
  end

  def execute
    raise ArgumentError, 'boom'
  end
end
