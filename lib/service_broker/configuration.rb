module ServiceBroker
  # Settings of the library. One instance lives behind ServiceBroker.config.
  class Configuration
    SETTINGS = %i[
      async_runner error_reporter error_dedup message_builder logger instrumenter retry_on
      job_parent_name max_retries max_step_depth
    ].freeze

    attr_reader(*SETTINGS, :pass_through_errors)

    def initialize
      @async_runner = nil
      @error_reporter = ->(error, **) {}
      @error_dedup = ->(context:, error_class:) { !context.nil? || !error_class.nil? }
      @message_builder = MessageBuilder.new
      @logger = ->(line) {}
      @instrumenter = nil
      @retry_on = {}
      @job_parent_name = ServiceBroker.default_job_parent_name
      @max_retries = 25
      @max_step_depth = 10
      @pass_through_errors = ServiceBroker.default_pass_through_errors.dup
    end

    def max_step_depth=(value)
      unless value.is_a?(::Integer) && value.positive?
        raise ConfigurationError, 'max_step_depth must be a positive number'
      end

      @max_step_depth = value
    end

    def pass_through_errors=(classes)
      @pass_through_errors = Array(classes)
    end

    def async_runner
      @async_runner ||= default_async_runner
    end

    # The runner as it is set, without building the default one.
    def async_runner_or_nil
      @async_runner
    end

    def async_runner=(runner)
      %i[enqueue job_name_for].each do |method|
        next if runner.respond_to?(method)

        raise ConfigurationError, "async runner must answer to #{method}"
      end

      @async_runner = runner
    end

    def error_reporter=(callable)
      @error_reporter = check_callable(callable, :error_reporter)
    end

    def error_dedup=(callable)
      @error_dedup = check_callable(callable, :error_dedup)
    end

    def message_builder=(callable)
      @message_builder = check_callable(callable, :message_builder)
    end

    def logger=(callable)
      @logger = check_callable(callable, :logger)
    end

    def instrumenter=(callable)
      @instrumenter = callable.nil? ? nil : check_callable(callable, :instrumenter)
    end

    def retry_on=(rules)
      @retry_on = rules.to_h { |name, options| [name.to_s, options.transform_keys(&:to_sym)] }
    end

    def job_parent_name=(name)
      @job_parent_name = name.to_s
    end

    def max_retries=(count)
      @max_retries = Integer(count)
    end

    def to_h
      SETTINGS.to_h { |name| [name, public_send(name)] }
    end

    private

    def check_callable(callable, name)
      raise ConfigurationError, "#{name} must answer to call" unless callable.respond_to?(:call)

      callable
    end

    def default_async_runner
      builder = ServiceBroker.default_runner_builder
      raise ConfigurationError, 'no async runner is set' unless builder

      builder.call
    end
  end
end
