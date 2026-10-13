class Probe::Sum < ServiceBroker::Operation
  required do
    integer :left
    integer :right
  end

  def execute
    left + right
  end
end
