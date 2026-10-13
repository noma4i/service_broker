require 'test_helper'

class ArrayFilterTest < BrokerTest
  def with_block(**)
    declare do
      required { array(:value, **) { integer } }

      def execute
        value
      end
    end
  end

  def code(input, **)
    with_block(**).validate(value: input).errors.symbolic['value']
  end

  def test_sb_04_32_declaration_needs_an_element_type
    assert_equal %i[class max_length min_length nils of],
                 ServiceBroker::Filters::Array.default_options.keys.sort
    assert_equal :array, code('a')
  end

  def test_sb_04_32_arrayize_and_an_empty_block_are_rejected
    assert_raises(ServiceBroker::DeclarationError) { with_block(arrayize: true) }

    error = assert_raises(ServiceBroker::DeclarationError) do
      declare { required { array(:value) { nil } } }
    end

    assert_match(/element type/, error.message)
  end

  def test_sb_04_32_class_option_types_the_elements
    operation = declare do
      required { array :value, class: ::String }

      def execute
        value
      end
    end

    assert_equal %w[a b], operation.call(value: %w[a b])
    assert_equal [nil, :class], operation.validate(value: ['a', 2]).errors.symbolic['value']
  end

  def test_sb_04_33_length_is_checked_before_the_elements
    assert_equal :min_length, code(['a'], min_length: 2)
    assert_equal :max_length, code(%w[a b c], max_length: 2)
  end

  def test_sb_04_33_element_transform_runs_for_every_element
    operation = declare do
      required { array(:value) { string transform: :upcase } }

      def execute
        value
      end
    end

    assert_equal %w[AB CD], operation.call(value: %w[ab cd])
  end

  def test_sb_04_33_every_wrong_element_is_reported_with_its_index
    assert_equal %i[integer integer integer], code(%w[a b c])
    assert_equal [nil, nil, :integer], code([1, 2, 'x'])
  end

  def test_sb_04_34_discard_invalid_keeps_the_valid_elements
    operation = declare do
      required { array(:value) { integer discard_invalid: true } }

      def execute
        value
      end
    end

    assert_equal [1, 3], operation.call(value: [1, 'a', 3])
  end

  def test_sb_04_35_codes
    assert_equal :nils, code(nil)
    assert_equal :empty, code('')
  end

  def test_sb_04_44_of_option_names_the_element_type
    operation = declare do
      required { array :value, of: :integer }

      def execute
        value
      end
    end

    assert_equal [1, 2], operation.call(value: ['1', 2])
    assert_equal [nil, :integer], operation.validate(value: [1, 'x']).errors.symbolic['value']
  end

  def test_sb_04_44_of_option_passes_the_element_options
    operation = declare do
      required { array :value, of: :string, in: %w[red blue] }

      def execute
        value
      end
    end

    assert_equal %w[red], operation.call(value: ['red'])
    assert_equal [:in], operation.validate(value: ['green']).errors.symbolic['value']
  end

  def test_sb_04_44_of_option_refuses_a_block_and_a_class
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { array(:value, of: :integer) { integer } } }
    end
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { array :value, of: :integer, class: ::Integer } }
    end
  end
end
