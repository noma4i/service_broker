require 'test_helper'

class EnumFilterTest < BrokerTest
  SORTS = %w[count name].freeze

  def operation(**)
    declare do
      required { enum(:value, values: SORTS, **) }

      def execute
        value
      end
    end
  end

  def code(input, **)
    operation(**).validate(value: input).errors.symbolic['value']
  end

  def test_sb_04_42_values_option_is_required
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { enum :value } }
    end
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { enum :value, values: [] } }
    end
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { enum :value, values: SORTS, in: SORTS } }
    end
  end

  def test_sb_04_42_string_becomes_a_symbol_from_the_list
    assert_equal :count, operation.call(value: 'count')
    assert_equal :count, operation.call(value: :count)
    assert_equal :name, operation(values: %i[count name]).call(value: 'name')
  end

  def test_sb_04_43_error_codes
    assert_equal :nils, code(nil)
    assert_equal :empty, code('')
    assert_equal :enum, code(1)
    assert_equal :in, code('size')
    assert_equal %i[empty_is_nil nils values], ServiceBroker::Filters::Enum.default_options.keys.sort
  end
end
