require 'test_helper'

class SymbolFilterTest < BrokerTest
  def operation(**)
    declare do
      required { symbol(:value, **) }

      def execute
        value
      end
    end
  end

  def code(input, **)
    operation(**).validate(value: input).errors.symbolic['value']
  end

  def test_sb_04_21_accepts_symbols_and_non_empty_strings
    assert_equal :red, operation.call(value: 'red')
    assert_equal :red, operation.call(value: :red)
    assert_equal :empty, code('')
    assert_equal :symbol, code(1)
    assert_equal %i[empty_is_nil in nils], ServiceBroker::Filters::Symbol.default_options.keys.sort
  end

  def test_sb_04_22_in_compares_symbols
    assert_equal :red, operation(in: %i[red]).call(value: 'red')
    assert_equal :in, code('blue', in: %i[red])
    assert_equal :nils, code(nil)
  end
end
