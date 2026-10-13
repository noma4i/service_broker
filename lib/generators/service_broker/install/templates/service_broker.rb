ServiceBroker.configure do |config|
  # Puts operations into the queue. Replace it with your own runner when needed.
  # config.async_runner = ServiceBroker::ActiveJobAsync.new

  # Receives an exception of a failed operation.
  # config.error_reporter = ->(error, **context) { Sentry.capture_exception(error) }

  # Answers false to skip a repeated report.
  # config.error_dedup = ->(context:, error_class:) { true }

  # Builds the text of one error out of the input name and the code.
  # config.message_builder = ->(key, code, index: nil) { I18n.t("errors.#{code}", key: key) }

  # Receives one line about a call made with log: true.
  # config.logger = ->(line) { Rails.logger.info(line) }

  # Receives one event per call and per queueing.
  # config.instrumenter = ->(name, payload) { ActiveSupport::Notifications.instrument(name, payload) }

  # Repeats a queued operation after the named error class.
  # config.retry_on = { 'Faraday::TimeoutError' => { attempts: 3, wait: 5 } }

  # Parent of the generated job classes.
  config.job_parent_name = 'ApplicationJob'

  # Upper limit of retries of one queued operation.
  config.max_retries = 25
end
