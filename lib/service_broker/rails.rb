require 'active_record'
require 'active_job'
require 'global_id'

require_relative 'rails/filters/finder'
require_relative 'rails/filters/model'
require_relative 'rails/filters/gid'
require_relative 'rails/filters/record'
require_relative 'rails/active_job_async'
require_relative 'rails/operation_job'

module ServiceBroker
  Filters.replace(:finder, Filters::Finder)
  Filters.replace(:model, Filters::Model)
  Filters.replace(:gid, Filters::Gid)
  Filters.replace(:record, Filters::Record)

  self.transaction_runner = lambda do |&block|
    nested = ActiveRecord::Base.connection.transaction_open?

    ActiveRecord::Base.transaction(requires_new: nested) do
      block.call
    rescue RollbackSignal
      raise ActiveRecord::Rollback
    end
  end
  self.default_runner_builder = -> { ActiveJobAsync.new }
  self.default_job_parent_name = 'ActiveJob::Base'
  self.default_pass_through_errors = [ActiveRecord::Rollback, ActiveRecord::Deadlocked]

  reset_config!
end
