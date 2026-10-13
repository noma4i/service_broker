class Probe::ReadAccount < ServiceBroker::Operation
  required do
    finder :account, model: ::Probe::Account
  end

  def execute
    account.title
  end
end
