require 'test_helper'

class BooleanFilterTest < BrokerTest
  def operation(**)
    declare do
      required { boolean(:value, **) }

      def execute
        value
      end
    end
  end

  def code(input, **)
    operation(**).validate(value: input).errors.symbolic['value']
  end

  def test_sb_04_19_accepted_inputs
    {
      true => true, false => false, 1 => true, 0 => false,
      'true' => true, 'TRUE' => true, ' true ' => true, 'false' => false,
      '1' => true, '0' => false
    }.each do |input, expected|
      assert_equal expected, operation.call(value: input), input.inspect
    end
  end

  def test_sb_04_19_rejected_inputs
    ['yes', 'no', 'on', 'off', 't', 'f', 2, -1].each do |input|
      assert_equal :boolean, code(input), input.inspect
    end
  end

  def test_sb_04_20_default_options_and_codes
    assert_equal %i[empty_is_nil nils], ServiceBroker::Filters::Boolean.default_options.keys.sort
    assert_equal :nils, code(nil)
    assert_equal :empty, code('')
    assert_equal :boolean, code(2)
  end
end
