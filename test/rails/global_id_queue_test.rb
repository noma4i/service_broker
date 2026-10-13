require 'rails_helper'

class GlobalIdQueueTest < RailsBrokerTest
  def setup
    super
    ServiceBroker.config.async_runner = ServiceBroker::ActiveJobAsync.new
  end

  def test_sb_08_20_a_record_travels_as_a_global_id
    account = Probe::Account.create!(title: 'a')
    Probe::ReadAccount.call(account: account, async: true)
    job = enqueued_jobs.last

    assert_match(%r{gid://}, job[:args].last['account'].to_s)
    assert_equal 'a', perform(job)
  end

  def test_sb_08_20_every_way_of_naming_a_record_travels_the_same
    account = Probe::Account.create!(title: 'a')

    [
      { account: account },
      { account: account.to_global_id.to_s },
      { account: account.id }
    ].each do |arguments|
      enqueued_jobs.clear
      Probe::ReadAccount.call(async: true, **arguments)

      assert_equal 'a', perform(enqueued_jobs.last), arguments.inspect
    end
  end

  def test_sb_08_21_a_deleted_record_does_not_retry_the_job
    reported = []
    ServiceBroker.config.error_reporter = ->(error, **) { reported << error }
    account = Probe::Account.create!(title: 'a')
    Probe::ReadAccount.call(account: account.id, async: true)
    job = enqueued_jobs.last
    enqueued_jobs.clear
    account.destroy!
    perform(job)

    assert_empty enqueued_jobs
    assert_equal 1, reported.size
    assert_instance_of ServiceBroker::ValidationError, reported.first
  end

  def test_sb_07_19_an_unreadable_argument_is_reported_once
    reported = []
    ServiceBroker.config.error_reporter = ->(error, **) { reported << error }
    account = Probe::Account.create!(title: 'a')
    Probe::ReadAccount.call(account: account, async: true)
    job = enqueued_jobs.last
    account.destroy!
    enqueued_jobs.clear

    ActiveJob::Base.execute(job_data(job))

    assert_empty enqueued_jobs
    assert_equal 1, reported.size
    assert_instance_of ActiveJob::DeserializationError, reported.first
  end

  private

  # The data a worker reads out of the queue.
  def job_data(job)
    {
      'job_class' => job[:job].name, 'job_id' => 'probe-1', 'queue_name' => 'default',
      'arguments' => job[:args], 'executions' => 0, 'priority' => nil, 'provider_job_id' => nil,
      'locale' => 'en', 'timezone' => 'UTC', 'enqueued_at' => Time.now.utc.iso8601,
      'exception_executions' => {}, 'scheduled_at' => nil
    }
  end

  # Runs the job the way a worker does: the arguments come back deserialized.
  def perform(job)
    job[:job].perform_now(*ActiveJob::Arguments.deserialize(job[:args]))
  end
end
