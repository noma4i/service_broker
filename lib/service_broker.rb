require 'bigdecimal'
require 'date'
require 'time'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/hash/except'

require_relative 'service_broker/version'
require_relative 'service_broker/errors'
require_relative 'service_broker/outcome'
require_relative 'service_broker/message_builder'
require_relative 'service_broker/configuration'
require_relative 'service_broker/filters'
require_relative 'service_broker/filters/base'
require_relative 'service_broker/filters/string'
require_relative 'service_broker/filters/numeric'
require_relative 'service_broker/filters/boolean'
require_relative 'service_broker/filters/symbol'
require_relative 'service_broker/filters/temporal'
require_relative 'service_broker/filters/duck'
require_relative 'service_broker/filters/any'
require_relative 'service_broker/filters/enum'
require_relative 'service_broker/filters/file'
require_relative 'service_broker/filters/array'
require_relative 'service_broker/filters/hash'
require_relative 'service_broker/input_set'
require_relative 'service_broker/log'
require_relative 'service_broker/events'
require_relative 'service_broker/option_declarations'
require_relative 'service_broker/queueing'
require_relative 'service_broker/reporting'
require_relative 'service_broker/operation'
require_relative 'service_broker/inline_async'

require_relative 'service_broker/railtie' if defined?(Rails::Railtie)

module ServiceBroker
  Filters.register(:string, Filters::String)
  Filters.register(:integer, Filters::Integer)
  Filters.register(:float, Filters::Float)
  Filters.register(:decimal, Filters::Decimal)
  Filters.register(:boolean, Filters::Boolean)
  Filters.register(:symbol, Filters::Symbol)
  Filters.register(:date, Filters::Date)
  Filters.register(:time, Filters::Time)
  Filters.register(:duck, Filters::Duck)
  Filters.register(:object, Filters::Any)
  Filters.register(:enum, Filters::Enum)
  Filters.register(:file, Filters::File)
  Filters.register(:array, Filters::Array)
  Filters.register(:hash, Filters::Hash)

  MESSAGE_LIMIT = 500

  class << self
    attr_accessor :default_runner_builder, :transaction_runner, :default_job_parent_name
    attr_writer :default_pass_through_errors

    def default_pass_through_errors
      @default_pass_through_errors ||= []
    end

    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
      config
    end

    def reset_config!
      @config = Configuration.new
    end

    def indifferent(hash)
      ActiveSupport::HashWithIndifferentAccess.new(hash || {})
    end

    # Drops the bookkeeping keys a queue adds and gives back symbol keys.
    def symbolize(hash)
      (hash || {}).reject { |key, _| key.to_s.start_with?('_aj_') }
                  .to_h { |key, value| [key.to_sym, value] }
    end

    def argument_types(inputs)
      (inputs || {}).to_h { |name, value| [name.to_s, value.class.name] }
    end

    def exception_text(error)
      text = begin
        error.message
      rescue ::NoMethodError
        nil
      end

      "#{error.class}: #{text.to_s.empty? ? 'no message' : text}"[0, MESSAGE_LIMIT]
    end

    def transaction(&)
      runner = transaction_runner
      raise ConfigurationError, 'the safe option needs a transaction runner' unless runner

      runner.call(&)
    end
  end
end
