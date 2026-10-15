module ServiceBroker
  # Short declarations of the execution options of one operation class.
  module OptionDeclarations
    def queue(name)
      defaults(queue: name)
    end

    def wait(seconds)
      defaults(delay: seconds)
    end

    def priority(order)
      defaults(priority: order)
    end

    def async!
      defaults(async: true)
    end

    # Opt-in: an operation is never unique unless it says so. The job of this operation takes the
    # strategy from the job library while it waits in the queue.
    def unique(strategy = :until_executing, ttl: nil)
      @unique_options = { strategy: strategy, ttl: ttl }.compact
    end

    def unique_options
      @unique_options
    end

    def transactional!
      defaults(safe: true)
    end

    def log!
      defaults(log: true)
    end
  end
end
