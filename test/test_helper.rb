require 'minitest/autorun'
require 'service_broker'

require_relative 'support/probe/namespaces'
Dir[File.expand_path('support/**/*.rb', __dir__)].each { |file| require file }

module BrokerTestHelpers
  def setup
    super
    ServiceBroker.reset_config!
    ServiceBroker.config.async_runner = TestAsync.new
  end

  def teardown
    super
    ServiceBroker.reset_config!
  end

  def runner
    ServiceBroker.config.async_runner
  end

  # Declares an operation class for one test and removes it afterwards.
  def declare(parent = ServiceBroker::Operation, &block)
    klass = Class.new(parent)
    klass.class_eval(&block) if block
    klass
  end

  def codes(outcome)
    outcome.errors.symbolic
  end
end

class BrokerTest < Minitest::Test
  include BrokerTestHelpers
end
