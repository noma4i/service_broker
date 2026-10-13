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

    def transactional!
      defaults(safe: true)
    end

    def log!
      defaults(log: true)
    end
  end
end
