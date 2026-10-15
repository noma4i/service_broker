require 'rails_helper'

class ActiveJobAsyncTest < RailsBrokerTest
  def setup
    super
    ServiceBroker.config.async_runner = ServiceBroker::ActiveJobAsync.new
  end

  def test_sb_07_02_railtie_sets_the_active_job_runner
    ServiceBroker.reset_config!

    assert_instance_of ServiceBroker::ActiveJobAsync, ServiceBroker.config.async_runner
  end

  def test_sb_07_03_a_refused_enqueue_returns_nil
    parent = Class.new(ActiveJob::Base) { before_enqueue { throw :abort } }
    stub_name(parent, 'ProbeRefusingJob')
    Object.const_set(:ProbeRefusingJob, parent)
    ServiceBroker.config.job_parent_name = 'ProbeRefusingJob'
    forget_probe_jobs

    assert_nil Probe::Sum.call(left: 1, right: 2, async: true)
    assert_empty enqueued_jobs
  ensure
    forget_probe_jobs
    Object.send(:remove_const, :ProbeRefusingJob)
  end

  def test_sb_07_05_job_carries_the_operation_name
    Probe::Media::BuildThumbnail.call(width: 320, async: true)

    assert_equal 1, enqueued_jobs.size
    name = enqueued_jobs.last[:job].name

    assert_includes name, 'Probe::Media::BuildThumbnail'
    assert_equal enqueued_jobs.last[:job], name.constantize
  end

  def test_sb_07_06_job_class_is_built_once_per_operation
    runner = ServiceBroker.config.async_runner
    first = runner.job_class_for(Probe::Sum)
    second = runner.job_class_for(Probe::Sum)

    assert_same first, second

    classes = []
    threads = 2.times.map { Thread.new { classes << runner.job_class_for(Probe::Noop) } }
    threads.each(&:join)

    assert_equal 1, classes.map(&:object_id).uniq.size
  end

  def test_sb_07_09_value_without_a_queue_representation_is_rejected
    operation = declare do
      required { duck :payload, methods: [:read] }

      def execute
        payload.read
      end
    end

    payload = Object.new
    payload.define_singleton_method(:read) { 'data' }

    assert_raises(ServiceBroker::SerializationError) do
      operation.call(payload: payload, async: true)
    end
  end

  def test_sb_07_10_job_runs_the_operation_without_queueing_again
    Probe::Sum.call(left: 3, right: 4, async: true)
    job = enqueued_jobs.last
    enqueued_jobs.clear

    assert_equal 7, job[:job].perform_now(*job[:args])
    assert_empty enqueued_jobs
  end

  def test_sb_07_12_validation_error_discards_the_job
    reported = []
    ServiceBroker.config.error_reporter = ->(error, **) { reported << error }

    Probe::Sum.call(left: 'x', right: 4, async: true)
    job = enqueued_jobs.last
    enqueued_jobs.clear
    job[:job].perform_now(*job[:args])

    assert_empty enqueued_jobs
    assert_equal 1, reported.size
    assert_instance_of ServiceBroker::ValidationError, reported.first
  end

  def test_sb_07_13_retry_after_sets_the_next_run
    Probe::Throttling.call(async: true)
    job = enqueued_jobs.last
    enqueued_jobs.clear
    job[:job].perform_now(*job[:args])

    assert_equal 1, enqueued_jobs.size
    assert_in_delta 30, enqueued_jobs.last[:at] - Time.now.to_f, 5
  end

  def test_sb_07_13_retries_stop_at_max_retries
    ServiceBroker.config.max_retries = 1
    job_class = ServiceBroker.config.async_runner.job_class_for(Probe::Throttling)
    job = job_class.new('Probe::Throttling', {})
    job.executions = 2

    assert_raises(Probe::Throttled) { job.perform_now }
    assert_empty enqueued_jobs
  end

  def test_sb_07_14_job_parent_comes_from_the_settings
    parent = Class.new(ActiveJob::Base)
    stub_name(parent, 'Probe::ParentJob')
    Object.const_set(:ProbeParentJob, parent)
    ServiceBroker.config.job_parent_name = 'ProbeParentJob'

    job_class = ServiceBroker.config.async_runner.job_class_for(Probe::Boom)

    assert_equal parent, job_class.superclass
  ensure
    Object.send(:remove_const, :ProbeParentJob)
  end

  def test_sb_07_15_queue_delay_and_priority_reach_active_job
    Probe::Sum.call(left: 1, right: 2, async: true, queue: :media, delay: 300, priority: 10)
    job = enqueued_jobs.last

    assert_equal 'media', job[:queue]
    assert_equal 10, job[:priority]
    assert_in_delta 300, job[:at] - Time.now.to_f, 5
  end

  def test_sb_07_16_retry_on_repeats_a_named_error_class
    ServiceBroker.config.retry_on = { 'Probe::Flaky' => { attempts: 2, wait: 5 } }
    Probe::Flaking.call(async: true)
    job = enqueued_jobs.last
    enqueued_jobs.clear
    job[:job].perform_now(*job[:args])

    assert_equal 1, enqueued_jobs.size
    assert_in_delta 5, enqueued_jobs.last[:at] - Time.now.to_f, 3
  end

  def test_sb_07_16_retry_on_stops_at_its_attempts
    ServiceBroker.config.retry_on = { 'Probe::Flaky' => { attempts: 2, wait: 5 } }
    job_class = ServiceBroker.config.async_runner.job_class_for(Probe::Flaking)
    job = job_class.new('Probe::Flaking', {})
    job.executions = 2

    assert_raises(Probe::Flaky) { job.perform_now }
    assert_empty enqueued_jobs
  end

  def test_sb_07_17_retry_after_wins_over_the_configured_wait
    ServiceBroker.config.retry_on = { 'Probe::Throttled' => { attempts: 5, wait: 5 } }
    Probe::Throttling.call(async: true)
    job = enqueued_jobs.last
    enqueued_jobs.clear
    job[:job].perform_now(*job[:args])

    assert_equal 1, enqueued_jobs.size
    assert_in_delta 30, enqueued_jobs.last[:at] - Time.now.to_f, 5
  end

  def test_sb_07_18_a_fresh_process_resolves_the_job_name
    name = ServiceBroker.config.async_runner.job_name_for(Probe::Sum)
    container = ServiceBroker::Jobs
    container.send(:remove_const, :Sum) if container.const_defined?(:Sum, false)

    job_class = name.constantize

    assert_equal name, job_class.name
    assert_equal ServiceBroker.config.job_parent_name.constantize, job_class.superclass
    assert_includes job_class.ancestors, ServiceBroker::OperationJobBody
  end

  def test_sb_07_18_a_nested_namespace_resolves_its_job_name
    ServiceBroker.config.async_runner.job_name_for(Probe::Media::BuildThumbnail)
    media = ServiceBroker::Jobs.const_get(:Probe, false).const_get(:Media, false)
    media.send(:remove_const, :BuildThumbnail)

    job_class = 'ServiceBroker::Jobs::Probe::Media::BuildThumbnail'.constantize

    assert_includes job_class.ancestors, ServiceBroker::OperationJobBody
  end

  def test_sb_07_18_b_a_fresh_worker_resolves_a_nested_job_name_with_no_namespace_built
    name = ServiceBroker.config.async_runner.job_name_for(Probe::Media::BuildThumbnail)
    forget_probe_jobs

    job_class = name.constantize

    assert_equal name, job_class.name
    assert_includes job_class.ancestors, ServiceBroker::OperationJobBody
  ensure
    forget_probe_jobs
  end

  private

  def forget_probe_jobs
    ServiceBroker::Jobs.send(:remove_const, :Probe) if ServiceBroker::Jobs.const_defined?(:Probe, false)
  end

  def stub_name(klass, name)
    klass.define_singleton_method(:name) { name }
  end
end
