class Probe::SyncOnly < ServiceBroker::SyncOperation
  optional do
    string :name
  end

  def execute
    :done
  end
end
