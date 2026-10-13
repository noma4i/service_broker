class Probe::Tracing < ServiceBroker::Operation
  class << self
    attr_accessor :sink
  end

  required do
    string :label
  end

  def execute
    self.class.sink << label
    label
  end
end
