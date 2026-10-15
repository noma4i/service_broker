class Probe::UniqueSum < ServiceBroker::Operation
  unique :until_executing, ttl: 600

  required do
    integer :left
    integer :right
  end

  def execute
    left + right
  end
end
