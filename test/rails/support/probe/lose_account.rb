class Probe::LoseAccount < ServiceBroker::Operation
  required do
    finder :account, model: ::Probe::Account
  end

  def execute
    add_error(:account, :not_found)
  end
end
