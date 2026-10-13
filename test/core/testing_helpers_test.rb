require 'test_helper'
require 'service_broker/testing'

class TestingHelpersTest < BrokerTest
  include ServiceBroker::Testing

  def test_sb_13_01_loading_the_helpers_changes_no_setting
    runner_before = ServiceBroker.config.async_runner
    load File.expand_path('../../lib/service_broker/testing.rb', __dir__)

    assert_same runner_before, ServiceBroker.config.async_runner
  end

  def test_sb_13_02_queued_operations_are_recorded
    runner_before = ServiceBroker.config.async_runner

    queued = with_queued_operations do
      Probe::Sum.call(left: 1, right: 2, async: true, queue: :media, delay: 30, priority: 7)
      Probe::Noop.call(name: 'a', async: true)
    end

    assert_equal [Probe::Sum, Probe::Noop], queued.map(&:operation_class)
    assert_equal :media, queued.first.queue
    assert_equal 30, queued.first.delay
    assert_equal 7, queued.first.priority
    assert_equal 1, queued.first.arguments[:left]
    assert_same runner_before, ServiceBroker.config.async_runner
  end

  def test_sb_13_02_recording_works_without_a_configured_runner
    ServiceBroker.reset_config!

    queued = with_queued_operations { Probe::Noop.call(name: 'a', async: true) }

    assert_equal [Probe::Noop], queued.map(&:operation_class)
    assert_nil ServiceBroker.config.async_runner_or_nil
  end

  def test_sb_13_03_inline_operations_run_at_once
    runs = []
    operation = declare do
      define_method(:execute) { runs << :ran }
    end

    id = with_inline_operations { operation.call(async: true) }

    assert_equal [:ran], runs
    assert_match(/\Ainline:/, id)

    operation.call(async: true)

    assert_equal [:ran], runs
    assert_equal 1, runner.jobs.size
  end

  def test_sb_13_04_assert_operation_queued_reads_the_arguments
    with_queued_operations do
      Probe::Sum.call(left: 1, right: 2, async: true)

      assert_operation_queued(Probe::Sum, left: 1, right: 2)

      error = assert_raises(Minitest::Assertion) do
        assert_operation_queued(Probe::Sum, left: 9, right: 2)
      end

      assert_match(/Probe::Sum/, error.message)
    end
  end
end
