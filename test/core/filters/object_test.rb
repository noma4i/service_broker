require 'test_helper'

class ObjectFilterTest < BrokerTest
  def operation(**)
    declare do
      required { object(:value, **) }

      def execute
        value
      end
    end
  end

  def test_sb_04_40_accepts_any_value_but_nil
    thing = Object.new

    assert_same thing, operation.call(value: thing)
    assert_equal '', operation.call(value: '')
    assert_equal :nils, operation.validate(value: nil).errors.symbolic['value']
    assert_nil operation(nils: true).call(value: nil)
  end

  def test_sb_04_40_rejects_the_options_of_other_types
    %i[methods class empty_is_nil].each do |option|
      assert_raises(ServiceBroker::DeclarationError, option.to_s) do
        operation(**{ option => true })
      end
    end
  end

  def test_sb_04_41_only_code_is_nils
    assert_equal %i[nils], ServiceBroker::Filters::Any.default_options.keys

    [Object.new, '', 0, false, [], {}].each do |value|
      assert operation.validate(value: value).success?, value.inspect
    end
  end
end
