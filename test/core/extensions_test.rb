require 'test_helper'

class ExtensionsTest < BrokerTest
  def teardown
    ServiceBroker::Filters.unregister(:money)
    super
  end

  def money_filter
    Class.new(ServiceBroker::Filters::Base) do
      def self.default_options
        { nils: false, currency: 'AUD' }
      end

      def filter(value)
        return [value, :money] unless value.is_a?(::String) && value.match?(/\A\d+\z/)

        [[value.to_i, options[:currency]], nil]
      end
    end
  end

  def test_sb_09_01_registered_type_becomes_available
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { money :price } }
    end

    ServiceBroker::Filters.register(:money, money_filter)
    operation = declare do
      required { money :price }

      def execute
        price
      end
    end

    assert_equal [10, 'AUD'], operation.call(price: '10')
  end

  def test_sb_09_02_own_type_returns_a_value_and_a_code
    ServiceBroker::Filters.register(:money, money_filter)
    operation = declare { required { money :price } }

    assert_equal({ 'price' => :money }, operation.validate(price: 'x').errors.symbolic)
  end

  def test_sb_09_03_second_registration_of_a_taken_name_is_rejected
    assert_raises(ServiceBroker::DeclarationError) do
      ServiceBroker::Filters.register(:string, money_filter)
    end
  end

  def test_sb_09_03_replace_takes_a_taken_name
    previous = ServiceBroker::Filters.lookup(:string)
    ServiceBroker::Filters.replace(:string, money_filter)
    operation = declare do
      required { string :price }

      def execute
        price
      end
    end

    assert_equal [10, 'AUD'], operation.call(price: '10')
  ensure
    ServiceBroker::Filters.replace(:string, previous)
  end

  def test_sb_09_04_unknown_option_is_rejected_at_declaration
    error = assert_raises(ServiceBroker::DeclarationError) do
      declare { required { string :title, lenght: 5 } }
    end

    assert_match(/lenght/, error.message)
  end

  def test_sb_09_05_family_base_can_build_execute
    base = declare do
      abstract_methods :payload

      required { string :token }

      def execute
        [token, payload]
      end
    end
    child = declare(base) do
      private

      def payload
        :child_payload
      end
    end

    assert_equal ['t', :child_payload], child.call(token: 't')
  end

  def test_sb_09_06_missing_abstract_method_is_rejected_at_declaration
    base = declare do
      abstract_methods :payload

      def execute
        payload
      end
    end

    child = declare(base)
    error = assert_raises(ServiceBroker::DeclarationError) { child.call }

    assert_match(/payload/, error.message)
  end

  def test_sb_09_07_own_runner_needs_no_inheritance
    custom = Class.new do
      attr_reader :seen

      def initialize
        @seen = []
      end

      def enqueue(operation_class, inputs, queue:, delay:, priority:)
        @seen << [operation_class, inputs, queue, delay, priority]
        'custom:1'
      end

      def job_name_for(operation_class)
        operation_class.name
      end
    end.new

    ServiceBroker.config.async_runner = custom

    assert_equal 'custom:1', Probe::Sum.call(left: 1, right: 2, async: true)
    assert_equal 1, custom.seen.size
  end

  def test_sb_09_08_runner_without_the_two_methods_is_rejected
    assert_raises(ServiceBroker::ConfigurationError) do
      ServiceBroker.configure { |config| config.async_runner = Object.new }
    end
  end

  def test_sb_09_09_gem_opens_no_ruby_classes
    sources = Dir[File.expand_path('../../lib/**/*.rb', __dir__)]
              .map { |file| File.read(file) }.join("\n")

    refute_match(/^class (Class|Object|Hash|String|Array|Symbol)\b/, sources)
  end
end
