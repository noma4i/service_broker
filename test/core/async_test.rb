require 'test_helper'

class AsyncTest < BrokerTest
  def test_sb_07_01_operation_has_no_delay_method
    refute_respond_to Probe::Sum, :delay
    refute_respond_to Object, :delay
    refute_respond_to Class, :delay
  end

  def test_sb_07_01_core_has_no_method_missing_proxy
    Dir[File.expand_path('../../lib/service_broker/**/*.rb', __dir__)].each do |file|
      body = File.read(file)
      next unless body.include?('method_missing')

      refute_match(/enqueue/, body, file)
    end

    sources = Dir[File.expand_path('../../lib/service_broker/**/*.rb', __dir__)]
              .map { |file| File.read(file) }.join("\n")

    refute_match(/Class\.include/, sources)
  end

  def test_sb_07_02_runner_is_replaceable
    Probe::Sum.call(left: 1, right: 2, async: true)

    assert_equal 1, runner.jobs.size
    assert_equal Probe::Sum, runner.last.operation_class
  end

  def test_sb_07_02_core_without_a_runner_refuses_to_queue
    ServiceBroker.reset_config!

    assert_raises(ServiceBroker::ConfigurationError) do
      Probe::Sum.call(left: 1, right: 2, async: true)
    end
  end

  def test_sb_07_03_runner_answers_enqueue_and_job_name_for
    assert_respond_to runner, :enqueue
    assert_respond_to runner, :job_name_for
    assert_equal 'test:0', Probe::Sum.call(left: 1, right: 2, async: true)
  end

  def test_sb_07_04_inline_runner_executes_instead_of_queueing
    ServiceBroker.config.async_runner = ServiceBroker::InlineAsync.new
    done = []
    operation = declare do
      define_method(:execute) { done << :ran }
    end
    stub_const_name(operation, 'Probe::Inline')

    id = operation.call(async: true)

    assert_equal [:ran], done
    assert_equal 'inline:Probe::Inline', id
  end

  def test_sb_07_07_runner_names_the_operation
    assert_equal 'Probe::Sum', runner.job_name_for(Probe::Sum)
  end

  def test_sb_07_08_job_data_carries_the_class_and_the_options
    Probe::Sum.call(left: 1, right: 2, async: true, safe: true, soft: true)
    job = runner.last

    assert_equal Probe::Sum, job.operation_class
    assert_equal true, job.inputs[:safe]
    assert_equal true, job.inputs[:soft]
    refute job.inputs.key?(:async)
    assert_equal 1, job.inputs[:left]
  end

  def test_sb_07_11_async_call_does_not_wait
    sources = Dir[File.expand_path('../../lib/service_broker/**/*.rb', __dir__)]
              .map { |file| File.read(file) }.join("\n")

    refute_match(/\bsleep\b/, sources)
    refute_match(/Thread[^\n]*join/, sources)
  end

  def test_sb_07_15_queue_delay_and_priority_reach_the_runner
    Probe::Sum.call(left: 1, right: 2, async: true, queue: :media, delay: 300, priority: 10)
    job = runner.last

    assert_equal :media, job.queue
    assert_equal 300, job.delay
    assert_equal 10, job.priority
  end

  private

  # Gives an anonymous operation a name so job ids stay readable.
  def stub_const_name(klass, name)
    klass.define_singleton_method(:name) { name }
  end
end
