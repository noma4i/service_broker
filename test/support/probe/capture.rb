class Probe::Capture < ServiceBroker::Operation
  class << self
    attr_accessor :sink
  end

  required do
    integer :left
    integer :right
    string :label
  end

  def execute
    self.class.sink << { left: left, right: right, label: label }
  end
end
