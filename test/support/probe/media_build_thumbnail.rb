class Probe::Media::BuildThumbnail < ServiceBroker::Operation
  required do
    integer :width
  end

  def execute
    width * 2
  end
end
