require 'test_helper'

class ExecutionTest < BrokerTest
  def test_sb_05_02_call_takes_keyword_arguments_only
    assert_raises(ArgumentError) { Probe::Noop.call({ name: 'a' }) }
  end

  def test_sb_05_03_execute_does_not_run_with_wrong_inputs
    operation = declare do
      required { integer :limit }

      def execute
        raise 'execute must not run'
      end
    end

    assert_raises(ServiceBroker::ValidationError) { operation.call(limit: 'x') }
  end

  def test_sb_05_03_wrong_inputs_still_reach_the_queue
    Probe::Sum.call(left: 'x', right: 2, async: true)

    assert_equal 1, runner.jobs.size
  end

  def test_sb_05_04_validate_skips_execute
    operation = declare do
      required { string :name }

      def execute
        raise 'execute must not run'
      end
    end

    assert operation.validate(name: 'a').success?
  end

  def test_sb_05_05_run_sync_ignores_async
    assert_equal 7, Probe::Sum.run_sync(left: 3, right: 4, async: true)
    assert_empty runner.jobs
  end

  def test_sb_05_06_execution_option_defaults
    assert_equal(
      { safe: false, soft: false, async: false, queue: :default, delay: nil, priority: nil,
        log: false },
      ServiceBroker::Operation.execution_defaults
    )
  end

  def test_sb_05_07_class_defaults_are_inherited_and_overridden
    base = declare do
      defaults queue: :media, async: true

      def execute
        :done
      end
    end
    child = declare(base) { defaults queue: :mail }

    base.call
    child.call

    assert_equal %i[media mail], runner.jobs.map(&:queue)
    assert_equal :mail, child.execution_defaults[:queue]
    assert_equal :media, base.execution_defaults[:queue]
  end

  def test_sb_05_07_call_option_beats_the_class_default
    operation = declare do
      defaults queue: :media, async: true

      def execute
        :done
      end
    end

    operation.call(queue: :urgent)

    assert_equal :urgent, runner.last.queue
  end

  def test_sb_05_09_nested_call_does_not_inherit_options
    inner = Probe::Sum
    outer = declare do
      define_method(:execute) do
        inner.call(left: 'x', right: 2)
        :no_error
      rescue ServiceBroker::ValidationError
        :raised
      end
    end

    outcome = outer.call(soft: true)

    assert outcome.success?
    assert_equal :raised, outcome.result
  end

  def test_sb_05_12_safe_without_active_record_is_a_configuration_error
    assert_raises(ServiceBroker::ConfigurationError) { Probe::Sum.call(left: 1, right: 2, safe: true) }
  end

  def test_sb_05_13_plain_call_returns_the_result
    assert_equal 7, Probe::Sum.call(left: 3, right: 4)
  end

  def test_sb_05_13_wrong_input_raises_validation_error
    error = assert_raises(ServiceBroker::ValidationError) { Probe::Sum.call(left: 'x', right: 4) }

    assert_equal({ 'left' => :integer }, error.errors.symbolic)
  end

  def test_sb_05_13_exception_from_execute_reaches_the_caller
    assert_raises(ArgumentError) { Probe::Boom.call }
  end

  def test_sb_05_14_soft_call_returns_an_outcome
    outcome = Probe::Sum.call(left: 'x', right: 4, soft: true)

    assert_instance_of ServiceBroker::Outcome, outcome
    refute outcome.success?
  end

  def test_sb_05_14_soft_call_wraps_the_exception
    outcome = Probe::Boom.call(soft: true)

    refute outcome.success?
    assert_equal({ 'base' => :exception }, outcome.errors.symbolic)
    assert_equal ['ArgumentError: boom'], outcome.errors.message_list
  end

  def test_sb_05_14_soft_exception_message_is_cut_to_500_characters
    operation = declare do
      define_method(:execute) { raise ArgumentError, 'x' * 1000 }
    end

    message = operation.call(soft: true).errors.message_list.first

    assert_equal 500, message.length
  end

  def test_sb_05_15_outcome_fields
    success = Probe::Sum.call(left: 3, right: 4, soft: true)

    assert success.success?
    assert_equal 7, success.result
    assert_nil success.errors
    assert_equal({ 'left' => 3, 'right' => 4 }, success.inputs)
    assert_equal({ 'left' => 3, 'right' => 4 }, success.raw_inputs)

    failure = Probe::Sum.call(left: 'x', right: 4, soft: true)

    refute failure.success?
    assert_nil failure.result
    refute_nil failure.errors
    assert_nil failure.exception
    assert_equal 'x', failure.raw_inputs[:left]
    assert_instance_of ArgumentError, Probe::Boom.call(soft: true).exception
  end

  def test_sb_05_16_async_call_returns_a_job_id
    id = Probe::Sum.call(left: 3, right: 4, async: true)

    assert_equal 'test:0', id
    refute_equal 7, id
  end

  def test_sb_05_17_sync_operation_rejects_async
    assert_raises(ServiceBroker::AsyncForbidden) { Probe::SyncOnly.call(async: true) }
    refute Probe::SyncOnly.asyncable?
    assert ServiceBroker::Operation.asyncable?
  end

  def test_sb_05_18_log_option_writes_names_and_classes
    lines = []
    ServiceBroker.config.logger = ->(line) { lines << line }

    declare do
      required { string :token }

      def execute
        :done
      end
    end.call(token: 'secret-value', log: true)

    assert_equal 2, lines.size
    assert(lines.any? { |line| line.include?('token') && line.include?('String') })
    refute(lines.any? { |line| line.include?('secret-value') })
  end

  def test_sb_05_18_log_is_silent_by_default
    lines = []
    ServiceBroker.config.logger = ->(line) { lines << line }

    Probe::Sum.call(left: 1, right: 2)

    assert_empty lines
  end

  def test_sb_05_19_error_reporter_runs_once
    reported = []
    ServiceBroker.config.error_reporter = ->(error, **) { reported << error }

    assert_raises(ArgumentError) { Probe::Boom.call }
    Probe::Boom.call(soft: true)

    assert_equal 2, reported.size
    assert(reported.all?(ArgumentError))
  end

  def test_sb_05_20_block_reaches_execute
    operation = declare do
      def execute
        block_given? ? yield : :no_block
      end
    end

    assert_equal(7, operation.call { 7 })
    assert_equal 7, operation.call(soft: true) { 7 }.result
    assert_equal :no_block, operation.call
  end

  def test_sb_05_21_memo_runs_once_per_call
    calls = 0
    operation = declare do
      define_method(:execute) do
        2.times { memo(:value) { calls += 1 } }
        memo(:value)
      end
    end

    operation.call
    operation.call

    assert_equal 2, calls
  end

  def test_sb_05_23_short_declarations_of_the_class_options
    short = declare do
      queue :media
      wait 300
      priority 10
      async!
      transactional!
      log!
    end
    long = declare do
      defaults queue: :media, delay: 300, priority: 10, async: true, safe: true, log: true
    end

    assert_equal long.execution_defaults, short.execution_defaults
  end
end
