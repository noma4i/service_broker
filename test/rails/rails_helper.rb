require 'test_helper'
require 'active_record'
require 'active_job'
require 'rails/railtie'
require 'service_broker/railtie'
require 'service_broker/rails'

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = Logger.new(IO::NULL)
ActiveRecord::Base.logger = Logger.new(IO::NULL)
GlobalID.app = 'probe'
ActiveRecord::Base.include(GlobalID::Identification)
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :probe_accounts, force: true do |t|
    t.string :title
  end

  create_table :probe_notes, force: true do |t|
    t.string :body
    t.integer :probe_account_id
  end
end

class Probe::Account < ActiveRecord::Base
  self.table_name = 'probe_accounts'
  has_many :notes, class_name: 'Probe::Note', foreign_key: :probe_account_id
end

class Probe::Note < ActiveRecord::Base
  self.table_name = 'probe_notes'
end

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |file| require file }

class RailsBrokerTest < Minitest::Test
  include BrokerTestHelpers

  def setup
    super
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    Probe::Account.delete_all
  end

  def enqueued_jobs
    ActiveJob::Base.queue_adapter.enqueued_jobs
  end
end
