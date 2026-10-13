require 'test_helper'

class FiltersCommonTest < BrokerTest
  CORE_TYPES = %i[
    string integer float decimal boolean symbol date time duck file array hash
  ].freeze

  SCALAR_TYPES = %i[string integer float decimal boolean symbol date time].freeze

  # Declares one operation with a single input of the given type.
  def with_input(type, **options)
    extra = options
    declare do
      required do
        case type
        when :hash then hash(:value, **extra) { optional { string :any } }
        when :array then array(:value, **extra) { integer }
        when :duck then duck(:value, methods: [:read], **extra)
        else send(type, :value, **extra)
        end
      end

      def execute
        value
      end
    end
  end

  def code_for(type, input, **)
    with_input(type, **).validate(value: input).errors.symbolic['value']
  end

  def test_sb_04_01_every_core_type_is_declarable
    CORE_TYPES.each { |type| assert with_input(type), type.to_s }
  end

  def test_sb_04_01_unknown_type_is_rejected
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { money :value } }
    end
  end

  def test_sb_04_01_rails_types_are_absent_from_the_core
    %i[model finder gid].each do |type|
      assert_raises(ServiceBroker::DeclarationError, type.to_s) do
        declare { required { send(type, :value) } }
      end
    end
  end

  def test_sb_04_02_error_code_is_a_symbol
    assert_kind_of Symbol, code_for(:integer, 'abc')
  end

  def test_sb_04_03_raw_input_keeps_the_original_value
    CORE_TYPES.each do |type|
      wrong = Object.new
      outcome = with_input(type).validate(value: wrong)

      refute outcome.success?, type.to_s
      assert_same wrong, outcome.raw_inputs[:value], type.to_s
    end
  end

  def test_sb_04_04_nil_gives_nils_for_every_type
    CORE_TYPES.each { |type| assert_equal :nils, code_for(type, nil), type.to_s }
  end

  def test_sb_04_04_nils_option_accepts_nil
    CORE_TYPES.each do |type|
      assert_nil with_input(type, nils: true).call(value: nil), type.to_s
    end
  end

  def test_sb_04_05_empty_is_nil_turns_blank_into_nils
    SCALAR_TYPES.each do |type|
      assert_equal :nils, code_for(type, '', empty_is_nil: true), type.to_s
    end
  end

  def test_sb_04_05_empty_is_nil_is_rejected_on_other_types
    %i[duck file array hash].each do |type|
      assert_raises(ServiceBroker::DeclarationError, type.to_s) do
        with_input(type, empty_is_nil: true)
      end
    end
  end

  def test_sb_04_06_blank_string_gives_empty
    (CORE_TYPES - [:duck]).each { |type| assert_equal :empty, code_for(type, ''), type.to_s }
  end

  def test_sb_04_06_string_with_empty_option_accepts_blank
    assert_equal '', with_input(:string, empty: true).call(value: '')
  end

  def test_sb_04_07_no_silent_coercion
    assert_equal :integer, code_for(:integer, '12abc')
    assert_equal :integer, code_for(:integer, '3.7')
    assert_equal :boolean, code_for(:boolean, 'yes')
    assert_equal :float, code_for(:float, '1.2.3')
  end

  def test_sb_04_46_transform_runs_after_the_checks
    operation = declare do
      required { string :value, transform: :downcase, max_length: 5 }

      def execute
        value
      end
    end

    assert_equal 'a@b.c', operation.call(value: 'A@B.C')
    assert_equal :max_length, operation.validate(value: 'ABCDEF').errors.symbolic['value']
  end

  def test_sb_04_46_transform_takes_a_callable
    operation = declare do
      required { array :value, of: :integer, transform: :sort }

      def execute
        value
      end
    end

    assert_equal [1, 2, 3], operation.call(value: [3, 1, 2])
  end

  def test_sb_04_47_failing_transform_gives_its_own_code
    operation = declare do
      required { string :value, transform: ->(_value) { raise 'boom' } }
    end

    assert_equal({ 'value' => :transform }, operation.validate(value: 'a').errors.symbolic)
  end
end
