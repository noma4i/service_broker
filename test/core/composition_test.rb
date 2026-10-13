require 'test_helper'

class CompositionTest < BrokerTest
  def setup
    super
    @trace = []
    @reports = []
    @lines = []
    ServiceBroker.config.error_reporter = ->(error, **) { @reports << error }
    ServiceBroker.config.logger = ->(line) { @lines << line }
  end

  def test_sb_14_01_step_returns_the_result_of_the_other_operation
    operation = declare do
      define_method(:execute) { step(Probe::Sum, left: 2, right: 3) }
    end

    assert_equal 5, operation.call
  end

  def test_sb_14_01_step_stays_private
    operation = declare { def execute = 1 }

    assert_raises(NoMethodError) { operation.new({}).step(Probe::Sum, left: 1, right: 1) }
  end

  def test_sb_14_02_failed_step_stops_the_operation
    trace = @trace
    operation = declare do
      define_method(:execute) do
        step(Probe::Rejecting, name: 'root')
        trace << :after_step
      end
    end

    outcome = operation.call(soft: true)

    refute outcome.success?
    assert_empty trace
  end

  def test_sb_14_03_step_errors_merge_at_the_top_level
    operation = declare do
      define_method(:execute) { step(Probe::Rejecting, name: 'root') }
    end

    outcome = operation.call(soft: true)

    assert_equal :not_allowed, codes(outcome)['error']
  end

  def test_sb_14_03_as_puts_step_errors_under_one_key
    operation = declare do
      define_method(:execute) { step(Probe::Rejecting, as: :payment, name: 'root') }
    end

    outcome = operation.call(soft: true)

    assert_equal :not_allowed, codes(outcome)['payment']['error']
  end

  def test_sb_14_04_step_passes_no_option_of_the_outer_call
    operation = declare do
      define_method(:execute) { step(Probe::Sum, left: 1, right: 1) }
    end

    operation.call(log: true)

    assert_equal 2, @lines.size
    assert(@lines.none? { |line| line.include?('Probe::Sum') })
  end

  def test_sb_14_05_exception_of_a_step_is_reported_once
    operation = declare do
      define_method(:execute) { step(Probe::Boom, name: 'x') }
    end

    outcome = operation.call(soft: true)

    refute outcome.success?
    assert_equal 1, @reports.size
  end

  def test_sb_14_05_pass_through_error_of_a_step_reaches_the_caller
    ServiceBroker.config.pass_through_errors = [ArgumentError]
    operation = declare do
      define_method(:execute) { step(Probe::Boom, name: 'x') }
    end

    assert_raises(ArgumentError) { operation.call(soft: true) }
  end

  def test_sb_14_06_before_runs_after_input_checks_and_before_execute
    trace = @trace
    operation = declare do
      required { integer :left }
      before Probe::Tracing, label: 'before'
      define_method(:execute) { trace << :execute }
    end
    Probe::Tracing.sink = trace

    operation.call(left: 1)

    assert_equal %w[before], trace.take(1)
    assert_equal :execute, trace.last
  end

  def test_sb_14_06_before_is_skipped_when_inputs_fail
    trace = @trace
    operation = declare do
      required { integer :left }
      before Probe::Tracing, label: 'before'
      def execute = 1
    end
    Probe::Tracing.sink = trace

    operation.call(left: 'x', soft: true)

    assert_empty trace
  end

  def test_sb_14_07_failed_before_keeps_execute_away
    trace = @trace
    operation = declare do
      before Probe::Rejecting, name: 'quota'
      define_method(:execute) { trace << :execute }
    end

    outcome = operation.call(soft: true)

    assert_equal :not_allowed, codes(outcome)['error']
    assert_empty trace
  end

  def test_sb_14_08_after_runs_and_keeps_the_result
    trace = @trace
    operation = declare do
      after Probe::Tracing, label: 'after'
      def execute = :done
    end
    Probe::Tracing.sink = trace

    assert_equal :done, operation.call
    assert_equal %w[after], trace
  end

  def test_sb_14_08_after_is_skipped_when_the_operation_fails
    trace = @trace
    operation = declare do
      required { integer :left }
      after Probe::Tracing, label: 'after'
      def execute = :done
    end
    Probe::Tracing.sink = trace

    operation.call(left: 'x', soft: true)

    assert_empty trace
  end

  def test_sb_14_10_failed_after_reports_and_keeps_the_result
    operation = declare do
      after Probe::Rejecting, name: 'late'
      def execute = :done
    end

    assert_equal :done, operation.call
    assert_equal 1, @reports.size
  end

  def test_sb_14_11_async_after_goes_to_the_queue
    operation = declare do
      after Probe::Sum, async: true, left: 2, right: ->(result) { result }
      def execute = 3
    end

    operation.call

    assert_equal 1, runner.jobs.size
    assert_equal({ left: 2, right: 3, safe: false, soft: false }, runner.last.inputs)
  end

  def test_sb_14_12_after_runs_only_when_the_condition_holds
    trace = @trace
    operation = declare do
      after Probe::Tracing, label: 'after', if: ->(result) { result == :yes }
      define_method(:execute) { :no }
    end
    Probe::Tracing.sink = trace

    operation.call

    assert_empty trace
  end

  def test_sb_14_13_step_values_come_from_names_callables_and_literals
    operation = declare do
      required { integer :left }
      after Probe::Capture, left: :left, right: ->(result) { result }, label: 'fixed'
      def execute = 7
    end
    Probe::Capture.sink = @trace

    operation.call(left: 4)

    assert_equal [{ left: 4, right: 7, label: 'fixed' }], @trace
  end

  def test_sb_14_14_declarations_of_the_base_run_first
    trace = @trace
    base = declare do
      after Probe::Tracing, label: 'base'
      def execute = :done
    end
    child = declare(base) { after Probe::Tracing, label: 'child' }
    Probe::Tracing.sink = trace

    child.call

    assert_equal %w[base child], trace
    assert_equal 1, base.after_steps.size
  end

  def test_sb_14_15_declaration_of_a_foreign_class_is_refused
    error = assert_raises(ServiceBroker::DeclarationError) do
      declare { after String, name: 'x' }
    end

    assert_includes error.message, 'String'
  end

  def test_sb_14_16_depth_over_the_limit_raises
    ServiceBroker.config.max_step_depth = 3
    operation = declare do
      optional { integer :level, default: 0 }
      define_method(:execute) { step(self.class, level: level + 1) }
    end

    assert_raises(ServiceBroker::StepDepthError) { operation.call }
  end

  def test_sb_14_16_depth_inside_the_limit_passes
    ServiceBroker.config.max_step_depth = 3
    operation = declare do
      optional { integer :level, default: 0 }
      define_method(:execute) { level >= 2 ? level : step(self.class, level: level + 1) }
    end

    assert_equal 2, operation.call
  end

  def test_sb_14_17_default_depth_limit_is_ten
    assert_equal 10, ServiceBroker.config.max_step_depth
  end

  def test_sb_14_17_depth_limit_refuses_zero
    assert_raises(ServiceBroker::ConfigurationError) { ServiceBroker.config.max_step_depth = 0 }
  end

  def test_sb_14_18_depth_belongs_to_one_call
    operation = declare do
      define_method(:execute) { step(Probe::Sum, left: 1, right: 1) }
    end

    operation.call

    assert_nil Thread.current[:service_broker_step_depth]
  end

  def test_sb_14_18_threads_keep_their_own_depth
    ServiceBroker.config.max_step_depth = 2
    deep = declare do
      optional { integer :level, default: 0 }
      define_method(:execute) { level >= 1 ? level : step(self.class, level: level + 1) }
    end
    flat = declare do
      define_method(:execute) { step(Probe::Sum, left: 1, right: 1) }
    end

    answers = [Thread.new { deep.call }, Thread.new { flat.call }].map(&:value)

    assert_equal [1, 2], answers
  end
end
