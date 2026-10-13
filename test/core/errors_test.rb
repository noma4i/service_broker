require 'test_helper'

class ErrorsTest < BrokerTest
  def nested_operation
    declare do
      required do
        string :title
        hash :address do
          required { string :city }
        end
      end
    end
  end

  def test_sb_06_01_error_set_shape
    outcome = nested_operation.validate(address: {})

    assert_instance_of ServiceBroker::Errors, outcome.errors
    assert_instance_of ServiceBroker::ErrorAtom, outcome.errors[:title]
    assert_instance_of ServiceBroker::Errors, outcome.errors[:address]
    assert_instance_of ServiceBroker::ErrorAtom, outcome.errors[:address][:city]
  end

  def test_sb_06_02_three_readings_of_the_error_set
    outcome = Probe::Sum.validate(left: 'x')
    errors = outcome.errors

    assert_equal({ 'left' => :integer, 'right' => :required }, errors.symbolic)
    assert_equal %w[left right], errors.message.keys
    assert_equal 2, errors.message_list.size
    assert(errors.message_list.all?(::String))
    refute(errors.any? { false })
    assert(errors.any? { true })
  end

  def test_sb_06_03_message_list_follows_the_declaration_order
    operation = declare do
      required do
        integer :one
        hash :two do
          required { integer :inner }
        end
        integer :three
      end
    end

    list = operation.validate(one: 'a', two: { inner: 'b' }, three: 'c').errors.message_list

    assert_equal 3, list.size
    assert_match(/one/i, list[0])
    assert_match(/inner/i, list[1])
    assert_match(/three/i, list[2])
  end

  def test_sb_06_04_error_atom_fields
    atom = Probe::Noop.validate.errors[:name]

    assert_equal :name, atom.key
    assert_equal :required, atom.symbolic
    assert_kind_of ::String, atom.message
    assert_nil atom.index

    operation = declare { required { array(:ids) { integer } } }
    element = operation.validate(ids: [1, 'x']).errors[:ids][1]

    assert_equal 1, element.index
  end

  def test_sb_06_05_message_builder_can_be_replaced
    ServiceBroker.config.message_builder = ->(key, code, index: nil) { "#{key}/#{code}/#{index}" }

    assert_equal ['name/required/'], Probe::Noop.validate.errors.message_list
  end

  def test_sb_06_06_explicit_message_is_kept
    operation = declare do
      required { string :name }

      def execute
        :done
      end

      private

      def validate
        add_error(:name, :too_short, 'Name is far too short')
      end
    end

    assert_equal ['Name is far too short'], operation.validate(name: 'a').errors.message_list
  end

  def test_sb_06_07_error_code_must_be_a_symbol
    assert_raises(ArgumentError) { ServiceBroker::ErrorAtom.new(:name, 'bad') }

    operation = declare do
      def execute
        :done
      end

      private

      def validate
        add_error(:name, 'bad')
      end
    end

    assert_equal({ 'base' => :exception }, operation.call(soft: true).errors.symbolic)
  end

  def test_sb_06_08_throw_error_stops_the_operation
    outcome = Probe::Rejecting.call(name: 'root', soft: true)

    refute outcome.success?
    assert_equal({ 'error' => :not_allowed }, outcome.errors.symbolic)
    assert_equal ["Name 'root' is not allowed"], outcome.errors.message_list

    assert_raises(ServiceBroker::ValidationError) { Probe::Rejecting.call(name: 'root') }
  end

  def test_sb_06_09_structured_error_keeps_its_fields
    operation = declare do
      def execute
        throw_structured_error(code: :rate_limited, retry_after: 30, message: 'Too many calls')
      end
    end

    outcome = operation.call(soft: true)

    refute outcome.success?
    assert_equal :rate_limited, outcome.errors[:code]
    assert_equal 30, outcome.errors[:retry_after]
    assert_equal ['Too many calls'], outcome.errors.message_list
  end

  def test_sb_06_10_add_error_in_validate_skips_execute
    operation = declare do
      required { string :name }

      def execute
        raise 'execute must not run'
      end

      private

      def validate
        add_error(:name, :rejected)
      end
    end

    assert_equal({ 'name' => :rejected }, operation.call(name: 'a', soft: true).errors.symbolic)
  end

  def test_sb_06_11_merge_errors_keeps_the_keys
    inner = Probe::Sum
    operation = declare do
      define_method(:execute) do
        merge_errors(inner.call(left: 'x', right: 'y', soft: true).errors)
        :merged
      end
    end

    outcome = operation.call(soft: true)

    refute outcome.success?
    assert_equal({ 'left' => :integer, 'right' => :integer }, outcome.errors.symbolic)
  end

  def test_sb_06_11_a_structured_failure_keeps_its_fields_when_merged
    inner = declare do
      def execute
        throw_structured_error(code: :rate_limited, retry_after: 30, message: 'too many')
      end
    end
    operation = declare do
      define_method(:execute) do
        merge_errors(inner.call(soft: true).errors)
        :merged
      end
    end

    errors = operation.call(soft: true).errors

    assert_equal :rate_limited, errors[:base][:code]
    assert_equal 30, errors[:base][:retry_after]
    assert_equal ['too many'], errors.message_list
  end

  def test_sb_06_12_exception_classes
    assert_operator ServiceBroker::ValidationError, :<, ServiceBroker::Error
    assert_operator ServiceBroker::DeclarationError, :<, ServiceBroker::Error
    assert_operator ServiceBroker::AsyncForbidden, :<, ServiceBroker::Error
    assert_operator ServiceBroker::SerializationError, :<, ServiceBroker::Error
    assert_operator ServiceBroker::ConfigurationError, :<, ServiceBroker::Error
    assert_operator ServiceBroker::Error, :<, StandardError
    refute_operator ServiceBroker::Error, :<, RuntimeError
  end

  def test_sb_06_13_validation_error_text_and_errors
    error = assert_raises(ServiceBroker::ValidationError) { Probe::Sum.call(left: 'x') }

    assert_equal error.errors.message_list.join('. '), error.message
    assert_equal({ 'left' => :integer, 'right' => :required }, error.errors.symbolic)
  end

  def test_sb_06_14_declaration_error_fires_without_a_call
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { string :execute } }
    end
  end

  def test_sb_06_15_dedup_can_stop_the_report
    reported = []
    lines = []
    ServiceBroker.config.error_reporter = ->(error, **) { reported << error }
    ServiceBroker.config.error_dedup = ->(context:, error_class:) { context.nil? && error_class.nil? }
    ServiceBroker.config.logger = ->(line) { lines << line }

    Probe::Boom.call(soft: true)

    assert_empty reported
    assert_equal 1, lines.size
    assert_match(/ArgumentError/, lines.first)
  end

  def test_sb_06_15_dedup_receives_context_and_error_class
    seen = []
    ServiceBroker.config.error_dedup = lambda do |context:, error_class:|
      seen << [context, error_class]
      true
    end

    Probe::Boom.call(soft: true)

    assert_equal [[Probe::Boom.name, 'ArgumentError']], seen
  end

  def test_sb_06_16_failing_reporter_does_not_replace_the_error
    ServiceBroker.config.error_reporter = ->(*) { raise TypeError, 'reporter is broken' }
    lines = []
    ServiceBroker.config.logger = ->(line) { lines << line }

    assert_raises(ArgumentError) { Probe::Boom.call }
    assert(lines.any? { |line| line.include?('TypeError') })
  end

  def test_sb_05_22_report_context_reaches_the_reporter
    seen = []
    ServiceBroker.config.error_reporter = ->(_error, **context) { seen << context }

    operation = declare do
      def execute
        raise ArgumentError, 'boom'
      end

      private

      def report_context
        { tenant: 'probe', retries: 2 }
      end
    end

    operation.call(soft: true)

    assert_equal 'probe', seen.first[:tenant]
    assert_equal 2, seen.first[:retries]
    assert seen.first.key?(:argument_types)
  end

  def test_sb_05_22_failing_report_context_keeps_the_original_error
    operation = declare do
      def execute
        raise ArgumentError, 'boom'
      end

      private

      def report_context
        raise TypeError, 'context is broken'
      end
    end

    assert_raises(ArgumentError) { operation.call }
  end
end
