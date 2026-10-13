require 'test_helper'

class NumericFiltersTest < BrokerTest
  def operation(type, **)
    declare do
      required { send(type, :value, **) }

      def execute
        value
      end
    end
  end

  def code(type, input, **)
    operation(type, **).validate(value: input).errors.symbolic['value']
  end

  def test_sb_04_13_three_numeric_types_share_their_options
    keys = %i[empty_is_nil in max min nils]

    %i[Integer Float Decimal].each do |name|
      filter = ServiceBroker::Filters.const_get(name)

      assert_equal keys, filter.default_options.keys.sort, name.to_s
    end
  end

  def test_sb_04_14_integer_accepts_integers_and_whole_number_strings
    assert_equal(-12, operation(:integer).call(value: '-12'))
    assert_equal 12, operation(:integer).call(value: 12)
    assert_equal :integer, code(:integer, '12abc')
    assert_equal :integer, code(:integer, '3.7')
    assert_equal :integer, code(:integer, 3.0)
    assert_equal :integer, code(:integer, BigDecimal('3'))
  end

  def test_sb_04_15_float_accepts_numbers_and_number_strings
    assert_in_delta 1000.0, operation(:float).call(value: '1e3')
    assert_in_delta 3.0, operation(:float).call(value: 3)
    assert_in_delta 0.5, operation(:float).call(value: BigDecimal('0.5'))
    assert_in_delta 0.5, operation(:float).call(value: Rational(1, 2))
    assert_equal :float, code(:float, '1.2.3')
  end

  def test_sb_04_16_decimal_keeps_precision_and_rejects_floats
    assert_equal BigDecimal('0.1'), operation(:decimal).call(value: '0.1')
    assert_equal BigDecimal('2'), operation(:decimal).call(value: 2)
    assert_equal :decimal, code(:decimal, 0.1)
  end

  def test_sb_04_17_bounds_are_inclusive_and_in_runs_after_coercion
    assert_equal 5, operation(:integer, min: 5).call(value: 5)
    assert_equal 5, operation(:integer, max: 5).call(value: 5)
    assert_equal 2, operation(:integer, in: [1, 2]).call(value: '2')
  end

  def test_sb_04_18_error_codes
    { integer: '12abc', float: 'x', decimal: 0.1 }.each do |type, bad|
      assert_equal :nils, code(type, nil), type.to_s
      assert_equal :empty, code(type, ''), type.to_s
      assert_equal type, code(type, bad), type.to_s
      assert_equal :min, code(type, 1, min: 2), type.to_s
      assert_equal :max, code(type, 3, max: 2), type.to_s
      assert_equal :in, code(type, 3, in: [1, 2]), type.to_s
    end
  end
end
