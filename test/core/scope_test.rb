require 'test_helper'

class ScopeTest < BrokerTest
  LIB = File.expand_path('../../lib', __dir__)

  def lib_files(pattern)
    Dir[File.join(LIB, pattern)]
  end

  def test_sb_01_01_operation_checks_inputs_and_runs_execute
    assert_equal 7, Probe::Sum.call(left: 3, right: 4)
  end

  def test_sb_01_02_core_names_no_external_reporting_libraries
    sources = lib_files('service_broker/**/*.rb').map { |file| File.read(file) }.join("\n")

    %w[Sentry Faraday Hashie GoodJob Sidekiq].each do |name|
      refute_includes sources, name
    end
  end

  def test_sb_01_03_replaces_the_previous_base_class_names
    refute ServiceBroker.const_defined?(:ServiceObject)
    refute Object.const_defined?(:ServiceObject)
  end

  def test_sb_01_07_defines_every_public_name
    %i[
      Operation SyncOperation Outcome Errors ErrorAtom ValidationError AsyncForbidden
      SerializationError ConfigurationError InlineAsync
    ].each do |name|
      assert ServiceBroker.const_defined?(name), "missing ServiceBroker::#{name}"
    end

    assert ServiceBroker::Filters.const_defined?(:Base)
    assert_respond_to ServiceBroker, :config
    assert_respond_to ServiceBroker, :configure
  end

  def test_sb_01_08_keeps_active_record_out_of_the_core
    core = lib_files('service_broker/**/*.rb')
           .reject { |file| file.include?('/rails') || file.end_with?('railtie.rb') }
    sources = core.map { |file| File.read(file) }.join("\n")

    refute_includes sources, 'ActiveRecord'
    refute_includes sources, 'ActiveJob'
  end

  def test_sb_01_09_core_require_loads_no_active_record
    loaded = `#{RbConfig.ruby} -I#{LIB} -e 'require "service_broker"; puts $LOADED_FEATURES'`

    refute_match(/active_record/, loaded)
    refute_match(/active_job/, loaded)
  end
end
