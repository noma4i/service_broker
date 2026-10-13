require 'rails_helper'

class RailsInputsTest < RailsBrokerTest
  def finder_operation(**)
    declare do
      required { finder(:account, model: ::Probe::Account, **) }

      def execute
        account
      end
    end
  end

  def model_operation(**)
    declare do
      required { model(:account, class: ::Probe::Account, **) }

      def execute
        account
      end
    end
  end

  def test_sb_08_01_rails_types_are_declarable_with_rails_loaded
    assert finder_operation
    assert model_operation
    assert(declare { required { gid :account } })
  end

  def test_sb_08_02_railtie_is_defined
    assert ServiceBroker.const_defined?(:Railtie)
  end

  def test_sb_08_03_settings_list
    assert_equal %i[
      async_runner error_dedup error_reporter instrumenter job_parent_name logger max_retries
      message_builder retry_on
    ], ServiceBroker.config.to_h.keys.sort
  end

  def test_sb_08_05_finder_takes_a_record_an_id_or_a_global_id
    account = Probe::Account.create!(title: 'a')
    note = Probe::Note.create!(body: 'b')

    assert_equal account, finder_operation.call(account: account.id)
    assert_equal account, finder_operation.call(account: account)
    assert_equal account, finder_operation.call(account: account.to_global_id.to_s)
    assert_equal :not_found,
                 finder_operation.validate(account: note.to_global_id.to_s).errors.symbolic['account']
  end

  def test_sb_08_05_finder_needs_the_model_option
    error = assert_raises(ServiceBroker::DeclarationError) do
      declare { required { finder :account } }
    end

    assert_match(/model/, error.message)
  end

  def test_sb_08_05_finder_rejects_a_model_name_as_string
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { finder :account, model: 'Probe::Account' } }
    end
  end

  def test_sb_08_06_finder_default_options
    assert_equal %i[model new_records nils preload unscoped],
                 ServiceBroker::Filters::Finder.default_options.keys.sort
  end

  def test_sb_08_07_finder_codes
    account = Probe::Account.create!(title: 'a')
    operation = finder_operation

    assert_equal :nils, operation.validate(account: nil).errors.symbolic['account']
    assert_equal :empty, operation.validate(account: '').errors.symbolic['account']
    assert_equal :not_found, operation.validate(account: account.id + 1_000).errors.symbolic['account']
    assert_equal :model,
                 operation.validate(account: Probe::Note.create!(body: 'b')).errors.symbolic['account']
    assert_equal :new_records, operation.validate(account: Probe::Account.new).errors.symbolic['account']
    assert_equal :not_found, operation.validate(account: 'gid://probe/Probe::Missing/1').errors.symbolic['account']
  end

  def test_sb_08_08_finder_reads_the_record_once
    account = Probe::Account.create!(title: 'a')
    queries = count_queries { finder_operation.call(account: account.id) }

    assert_equal 1, queries
  end

  def test_sb_08_08_preload_adds_one_read
    account = Probe::Account.create!(title: 'a')
    queries = count_queries { finder_operation(preload: :notes).call(account: account.id) }

    assert_equal 2, queries
  end

  def test_sb_08_09_model_takes_objects_only
    account = Probe::Account.create!(title: 'a')

    assert_equal account, model_operation.call(account: account)
    assert_equal :model, model_operation.validate(account: account.id).errors.symbolic['account']
  end

  def test_sb_08_09_builder_option_is_rejected
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { model :account, class: ::Probe::Account, builder: Probe::Sum } }
    end
  end

  def test_sb_08_10_unsaved_record_needs_the_option
    assert_equal :new_records, model_operation.validate(account: Probe::Account.new).errors.symbolic['account']
    assert_instance_of Probe::Account, model_operation(new_records: true).call(account: Probe::Account.new)
  end

  def test_sb_08_10_object_without_new_record_passes
    plain = Class.new { def self.name = 'Plain' }
    operation = declare do
      required { model :value, class: plain }

      def execute
        value
      end
    end

    object = plain.new

    assert_same object, operation.call(value: object)
  end

  def test_sb_08_11_gid_resolves_a_record
    account = Probe::Account.create!(title: 'a')
    operation = declare do
      required { gid :account }

      def execute
        account
      end
    end

    assert_equal account, operation.call(account: account.to_global_id.to_s)
  end

  def test_sb_08_11_gid_in_option_limits_the_classes
    note = Probe::Note.create!(body: 'b')
    operation = declare { required { gid :record, in: [::Probe::Account] } }

    assert_equal :in, operation.validate(record: note.to_global_id.to_s).errors.symbolic['record']
  end

  def test_sb_08_12_gid_codes
    account = Probe::Account.create!(title: 'a')
    locator = account.to_global_id.to_s
    account.destroy!
    operation = declare { required { gid :record } }

    assert_equal %i[in nils], ServiceBroker::Filters::Gid.default_options.keys.sort
    assert_equal :nils, operation.validate(record: nil).errors.symbolic['record']
    assert_equal :empty, operation.validate(record: '').errors.symbolic['record']
    assert_equal :gid, operation.validate(record: 'not-a-gid').errors.symbolic['record']
    assert_equal :gid, operation.validate(record: 'gid://probe/Probe::Missing/1').errors.symbolic['record']
    assert_equal :not_found, operation.validate(record: locator).errors.symbolic['record']
  end

  def test_sb_08_15_gem_names_no_application_directory
    sources = Dir[File.expand_path('../../lib/service_broker/**/*.rb', __dir__)]
              .map { |file| File.read(file) }.join("\n")

    refute_match(%r{app/services}, sources)
    refute_match(%r{app/operations}, sources)
  end

  def test_sb_08_16_gem_reads_no_request_state
    sources = Dir[File.expand_path('../../lib/service_broker/**/*.rb', __dir__)]
              .map { |file| File.read(file) }.join("\n")

    refute_match(/\bCurrent\b/, sources)
    refute_match(/RequestStore/, sources)
  end

  private

  def count_queries(&)
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      count += 1 unless payload[:name] == 'SCHEMA' || payload[:sql].start_with?('PRAGMA')
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end
end
