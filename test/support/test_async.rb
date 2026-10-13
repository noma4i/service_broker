# Records enqueued operations instead of touching a real queue.
class TestAsync
  Job = Struct.new(:operation_class, :inputs, :queue, :delay, :priority, :id)

  attr_reader :jobs

  def initialize
    @jobs = []
  end

  def enqueue(operation_class, inputs, queue:, delay:, priority:)
    id = "test:#{@jobs.size}"
    @jobs << Job.new(operation_class, inputs, queue, delay, priority, id)
    id
  end

  def job_name_for(operation_class)
    operation_class.name
  end

  def last
    @jobs.last
  end

  def perform_last
    job = @jobs.last
    job.operation_class.run_sync(**job.inputs)
  end
end
