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

  def test_sb_08_21_a_deleted_record_ends_the_job_without_retry_or_report
    reported = []
    ServiceBroker.config.error_reporter = ->(error, **) { reported << error }
    account = Probe::Account.create!(title: 'a')
    Probe::ReadAccount.call(account: account.id, async: true)
    job = enqueued_jobs.last
    enqueued_jobs.clear
    account.destroy!
    perform(job)

    assert_equal [[], []], [enqueued_jobs, reported]
  end

  def test_sb_08_21_a_not_found_the_operation_adds_itself_is_reported
    reported = []
    ServiceBroker.config.error_reporter = ->(error, **) { reported << error }
    account = Probe::Account.create!(title: 'a')
    Probe::LoseAccount.call(account: account.id, async: true)
    job = enqueued_jobs.last
    enqueued_jobs.clear
    perform(job)

    assert_equal [[], [ServiceBroker::ValidationError]], [enqueued_jobs, reported.map(&:class)]
  end

  def test_sb_07_19_an_argument_of_a_deleted_record_ends_the_job_quietly
    reported = []
    ServiceBroker.config.error_reporter = ->(error, **) { reported << error }
    account = Probe::Account.create!(title: 'a')
    Probe::ReadAccount.call(account: account, async: true)
    job = enqueued_jobs.last
    account.destroy!
    enqueued_jobs.clear

    ActiveJob::Base.execute(job_data(job))

    assert_equal [[], []], [enqueued_jobs, reported]
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
