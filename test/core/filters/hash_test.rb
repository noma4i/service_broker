require 'test_helper'

class HashFilterTest < BrokerTest
  def operation(**)
    declare do
      required do
        hash(:value, **) do
          required { string :city }
          optional { integer :zip }
        end
      end

      def execute
        value
      end
    end
  end

  def code(input, **)
    operation(**).validate(value: input).errors.symbolic['value']
  end

  def test_sb_04_36_declares_required_and_optional_keys
    assert_equal %i[nils of], ServiceBroker::Filters::Hash.default_options.keys.sort
    assert_equal({ 'city' => 'Perth', 'zip' => 6000 },
                 operation.call(value: { city: 'Perth', zip: '6000' }))
    assert_equal({ 'city' => 'Perth' }, operation.call(value: { city: 'Perth' }))
    assert_equal({ 'city' => :required }, code({}))
  end

  def test_sb_04_37_unknown_nested_key_is_an_error
    assert_equal({ 'extra' => :unknown_input }, code({ city: 'Perth', extra: 1 }))
  end

  def test_sb_04_37_allow_unknown_does_not_reach_the_nested_hash
    operation = declare do
      allow_unknown true
      required do
        hash :value do
          required { string :city }
        end
      end
    end

    outcome = operation.validate(value: { city: 'Perth', extra: 1 })

    assert_equal({ 'value' => { 'extra' => :unknown_input } }, outcome.errors.symbolic)
  end

  def test_sb_04_38_accepts_objects_that_answer_to_hash
    carrier = Object.new
    carrier.define_singleton_method(:to_hash) { { city: 'Perth' } }

    checked = operation.call(value: carrier)

    assert_equal 'Perth', checked[:city]
    assert_equal 'Perth', checked['city']
  end

  def test_sb_04_38_rejects_objects_without_to_hash
    assert_equal :hash, code(Object.new)
  end

  def test_sb_04_39_codes
    assert_equal :nils, code(nil)
    assert_equal :empty, code('')
  end

  def test_sb_04_45_of_option_types_every_value
    operation = declare do
      required { hash :value, of: :integer }

      def execute
        value
      end
    end

    assert_equal({ 'a' => 1, 'b' => 2 }, operation.call(value: { a: '1', b: 2 }))
    assert_equal({ 'b' => :integer }, operation.validate(value: { a: 1, b: 'x' }).errors.symbolic['value'])
  end

  def test_sb_04_45_of_option_refuses_a_block
    assert_raises(ServiceBroker::DeclarationError) do
      declare do
        required do
          hash :value, of: :integer do
            required { string :city }
          end
        end
      end
    end
  end
end
