require 'test_helper'

class StringFilterTest < BrokerTest
  def operation(**)
    declare do
      required { string(:value, **) }

      def execute
        value
      end
    end
  end

  def code(input, **)
    operation(**).validate(value: input).errors.symbolic['value']
  end

  def test_sb_04_08_default_options
    assert_equal %i[
      allow_control_characters empty empty_is_nil in matches max_length min_length nils strict strip
    ], ServiceBroker::Filters::String.default_options.keys.sort

    defaults = ServiceBroker::Filters::String.default_options

    assert_equal true, defaults[:strip]
    assert_equal false, defaults[:strict]
    assert_equal false, defaults[:nils]
    assert_equal false, defaults[:empty_is_nil]
    assert_equal false, defaults[:empty]
    assert_nil defaults[:min_length]
    assert_nil defaults[:max_length]
    assert_nil defaults[:matches]
    assert_nil defaults[:in]
    assert_equal false, defaults[:allow_control_characters]
  end

  def test_sb_04_09_length_is_checked_after_strip
    assert_equal 'ab', operation(max_length: 2).call(value: '  ab  ')
    assert_equal :empty, code('   ')
  end

  def test_sb_04_10_scalars_become_strings
    assert_equal '42', operation.call(value: 42)
    assert_equal 'red', operation.call(value: :red)
    assert_equal :string, code([1])
  end

  def test_sb_04_10_strict_rejects_every_non_string
    assert_equal :string, code(42, strict: true)
  end

  def test_sb_04_11_control_characters_are_removed
    assert_equal 'ab', operation.call(value: "a\u0000b")
    assert_equal "a\tb", operation(strip: false).call(value: "a\tb")
  end

  def test_sb_04_11_control_characters_can_be_kept
    assert_equal "a\u0000b", operation(allow_control_characters: true).call(value: "a\u0000b")
  end

  def test_sb_04_12_error_codes
    assert_equal :nils, code(nil)
    assert_equal :string, code([1])
    assert_equal :empty, code('')
    assert_equal :min_length, code('a', min_length: 2)
    assert_equal :max_length, code('abc', max_length: 2)
    assert_equal :in, code('x', in: %w[a b])
    assert_equal :matches, code('abc', matches: /\A\d+\z/)
  end
end
