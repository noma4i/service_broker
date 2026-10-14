require 'test_helper'

class EventsTest < BrokerTest
  def setup
    super
    @events = []
    ServiceBroker.config.instrumenter = ->(name, payload) { @events << [name, payload] }
  end

  def names
    @events.map(&:first)
  end

  def test_sb_12_01_one_event_per_call
    Probe::Sum.call(left: 1, right: 2)
    Probe::Boom.call(soft: true)

    assert_equal %w[service_broker.call service_broker.call], names
    first, second = @events.map(&:last)

    assert_equal 'Probe::Sum', first[:operation]
    assert first[:success]
    assert_operator first[:duration_ms], :>=, 0
    refute second[:success]
    assert_equal 'ArgumentError', second[:error_class]
    assert_equal false, second[:options][:async]
  end

  def test_sb_12_02_instrumenter_is_replaceable_and_its_failure_is_contained
    assert_equal 3, Probe::Sum.call(left: 1, right: 2)
    assert_equal 'service_broker.call', names.first

    lines = []
    ServiceBroker.config.logger = ->(line) { lines << line }
    ServiceBroker.config.instrumenter = ->(*) { raise TypeError, 'listener is broken' }

    assert_equal 3, Probe::Sum.call(left: 1, right: 2)
    assert(lines.any? { |line| line.include?('TypeError') })
  end

  def test_sb_12_02_no_events_without_an_instrumenter
    ServiceBroker.reset_config!
    ServiceBroker.config.async_runner = TestAsync.new

    assert_nil ServiceBroker.config.instrumenter
    assert_equal 3, Probe::Sum.call(left: 1, right: 2)
  end

  def test_sb_12_03_event_carries_input_names_and_classes_only
    declare do
      required { string :token }

      def execute
        :done
      end
    end.call(token: 'secret-value')

    payload = @events.first.last

    assert_equal({ 'token' => 'String' }, payload[:argument_types])
    refute_includes payload.inspect, 'secret-value'
  end

  def test_sb_12_04_refused_queueing_sends_no_event
    runner.define_singleton_method(:enqueue) { |*, **| nil }

    assert_nil Probe::Sum.call(left: 1, right: 2, async: true)
    assert_empty names
  end

  def test_sb_12_04_queueing_has_its_own_event
    Probe::Sum.call(left: 1, right: 2, async: true, queue: :media, delay: 60, priority: 5)

    assert_equal ['service_broker.enqueue'], names

    payload = @events.first.last

    assert_equal 'Probe::Sum', payload[:operation]
    assert_equal :media, payload[:queue]
    assert_equal 60, payload[:delay]
    assert_equal 5, payload[:priority]
  end
end
