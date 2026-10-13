require 'test_helper'

class ThreadSafetyTest < BrokerTest
  def test_sb_05_08_call_options_belong_to_one_call
    operation = declare do
      optional { boolean :slow, default: false }

      def execute
        sleep 0.05 if slow
        raise ArgumentError, 'boom'
      end
    end

    soft_result = nil
    hard_error = nil

    first = Thread.new { soft_result = operation.call(slow: true, soft: true) }
    second = Thread.new do
      operation.call
    rescue StandardError => e
      hard_error = e
    end
    [first, second].each(&:join)

    assert_instance_of ServiceBroker::Outcome, soft_result
    assert_instance_of ArgumentError, hard_error
  end
end
