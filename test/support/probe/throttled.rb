# Raised by probe operations to check the retry rule of the queue.
class Probe::Throttled < StandardError
  def retry_after
    30
  end
end
