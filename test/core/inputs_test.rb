require 'test_helper'

class InputsTest < BrokerTest
  def test_sb_03_01_input_declaration_lives_in_required_and_optional
    assert_raises(NoMethodError) do
      declare { string :title }
    end
  end

  def test_sb_03_02_missing_required_input_gives_required
    assert_equal({ 'name' => :required }, Probe::Noop.validate.errors.symbolic)
  end

  def test_sb_03_03_missing_optional_input_is_absent
    operation = declare do
      optional do
        string :first
        string :second
      end

      def execute
        [inputs.keys, second_present?]
      end
    end

    keys, present = operation.call(first: 'a')

    assert_equal ['first'], keys
    refute present
  end

  def test_sb_03_04_every_wrong_input_is_reported
    operation = declare do
      required do
        integer :one
        integer :two
        integer :three
      end
    end

    outcome = operation.validate(one: 'a', two: 'b', three: 'c')

    assert_equal %w[one two three], outcome.errors.symbolic.keys
  end

  def test_sb_03_05_input_gets_three_methods
    operation = declare do
      required { string :title }

      def execute
        [title, title_present?]
      end
    end

    assert_equal ['ab', true], operation.call(title: 'ab')
  end

  def test_sb_03_06_reserved_input_names_are_rejected
    %i[
      run run! run_sync call execute initialize validate inputs raw_inputs errors has_errors?
      outcome add_error merge_errors throw_error throw_structured_error memo report_context safe
      soft async queue delay priority log class clone dup freeze frozen? hash inspect
      instance_variables method methods nil? object_id public_send respond_to? send tap then to_s
    ].each do |name|
      error = assert_raises(ServiceBroker::DeclarationError, name.to_s) do
        declare { required { string name } }
      end

      assert_match(/#{Regexp.escape(name.to_s)}/, error.message)
    end
  end

  def test_sb_03_07_input_name_accepts_a_string
    operation = declare do
      required { string 'title' }

      def execute
        title
      end
    end

    assert_equal 'ab', operation.call(title: 'ab')
  end

  def test_sb_03_07_same_input_declared_twice_is_rejected
    assert_raises(ServiceBroker::DeclarationError) do
      declare do
        required do
          string :title
          string 'title'
        end
      end
    end
  end

  def test_sb_03_08_call_keys_accept_strings_and_keep_values
    payload = Object.new
    def payload.read = 'data'

    operation = declare do
      required { duck :payload, methods: [:read] }

      def execute
        payload
      end
    end

    assert_same payload, operation.call('payload' => payload)
  end

  def test_sb_03_09_unknown_key_is_an_error
    outcome = Probe::Noop.validate(name: 'a', titl: 'b')

    assert_equal({ 'titl' => :unknown_input }, outcome.errors.symbolic)
  end

  def test_sb_03_10_allow_unknown_keeps_the_key_out_of_inputs
    operation = declare do
      allow_unknown true
      required { string :name }

      def execute
        [inputs.keys, raw_inputs.keys]
      end
    end

    inputs, raw = operation.call(name: 'a', extra: 'b')

    assert_equal ['name'], inputs
    assert_equal %w[name extra], raw
  end

  def test_sb_03_11_star_input_types_every_other_key
    operation = declare do
      optional { integer :* }
    end

    assert_equal({ 'count' => :integer }, operation.validate(count: 'abc').errors.symbolic)
  end

  def test_sb_03_11_second_star_declaration_is_rejected
    assert_raises(ServiceBroker::DeclarationError) do
      declare do
        optional do
          integer :*
          string :*
        end
      end
    end
  end

  def test_sb_03_12_default_fills_a_missing_key
    operation = declare do
      optional { integer :limit, default: 10 }

      def execute
        limit
      end
    end

    assert_equal 10, operation.call
  end

  def test_sb_03_12_mutable_default_is_not_shared_between_calls
    operation = declare do
      optional { string :text, default: 'x' }

      def execute
        text << '!'
      end
    end

    assert_equal %w[x! x!], [operation.call.dup, operation.call.dup]
  end

  def test_sb_03_13_explicit_nil_takes_the_default
    operation = declare do
      optional { integer :limit, default: 10 }

      def execute
        limit
      end
    end

    assert_equal 10, operation.call(limit: nil)
  end

  def test_sb_03_14_required_input_with_default_rejects_explicit_nil
    operation = declare do
      required { integer :limit, default: 10 }

      def execute
        limit
      end
    end

    assert_equal 10, operation.call
    assert_equal({ 'limit' => :nils }, operation.validate(limit: nil).errors.symbolic)
  end

  def test_sb_03_15_callable_default_runs_once_per_call
    clock = (1..10).to_a
    operation = declare do
      optional { integer :stamp, default: -> { clock.shift } }

      def execute
        [stamp, stamp]
      end
    end

    first = operation.call
    second = operation.call

    assert_equal first.first, first.last
    refute_equal first.first, second.first
  end

  def test_sb_03_16_callable_value_is_not_called
    callback = ->(value) { value }
    operation = declare do
      required { duck :callback, methods: [:call] }

      def execute
        callback
      end
    end

    assert_same callback, operation.call(callback: callback)
  end

  def test_sb_03_17_discard_options_are_optional_only
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { string :title, discard_invalid: true } }
    end
  end

  def test_sb_03_17_discarded_key_takes_the_default
    operation = declare do
      optional { integer :limit, default: 10, discard_invalid: true }

      def execute
        limit
      end
    end

    assert_equal 10, operation.call(limit: 'abc')
  end

  def test_sb_03_18_error_key_renames_the_error
    operation = declare do
      required { string :title, error_key: :name }
    end

    assert_equal({ 'name' => :required }, operation.validate.errors.symbolic)
  end

  def test_sb_03_18_error_key_is_rejected_on_the_star_input
    assert_raises(ServiceBroker::DeclarationError) do
      declare { optional { integer :*, error_key: :any } }
    end
  end

  def test_sb_03_19_hash_input_needs_a_block
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { hash :payload } }
    end
  end

  def test_sb_03_20_array_input_needs_an_element_type
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { array :ids } }
    end
  end

  def test_sb_03_20_array_input_rejects_class_with_a_block
    assert_raises(ServiceBroker::DeclarationError) do
      declare { required { array(:ids, class: Integer) { integer } } }
    end
  end

  def test_sb_03_21_nested_hash_error_keeps_its_path
    operation = declare do
      required do
        hash :address do
          required { string :city }
        end
      end
    end

    outcome = operation.validate(address: {})

    assert_equal({ 'address' => { 'city' => :required } }, outcome.errors.symbolic)
  end

  def test_sb_03_21_array_error_keeps_its_index
    operation = declare do
      required { array(:ids) { integer } }
    end

    outcome = operation.validate(ids: [1, 2, 'x'])

    assert_equal [nil, nil, :integer], outcome.errors.symbolic['ids']
  end

  def test_sb_03_22_three_levels_of_nesting_report_the_deepest_key
    operation = declare do
      required do
        hash :one do
          required do
            hash :two do
              required { string :three }
            end
          end
        end
      end
    end

    outcome = operation.validate(one: { two: {} })

    assert_equal({ 'one' => { 'two' => { 'three' => :required } } }, outcome.errors.symbolic)
  end

  def test_sb_03_23_inputs_hold_checked_values_and_raw_inputs_hold_arguments
    operation = declare do
      required { integer :limit }

      def execute
        [inputs[:limit], raw_inputs[:limit]]
      end
    end

    assert_equal [5, '5'], operation.call(limit: '5')
  end

  def test_sb_03_23_inputs_are_not_public
    refute_includes Probe::Noop.public_instance_methods, :inputs
    refute_includes Probe::Noop.public_instance_methods, :raw_inputs
  end

  def test_sb_03_24_opaque_value_reaches_execute_unchanged
    io = StringIO.new('data')
    operation = declare do
      required { duck :io, methods: %i[read] }

      def execute
        io
      end
    end

    assert_same io, operation.call(io: io)
  end

  def test_sb_03_25_validate_runs_after_types_and_before_execute
    operation = declare do
      required { integer :limit }

      def execute
        raise 'execute must not run'
      end

      private

      def validate
        add_error(:limit, :too_big) if limit > 5
      end
    end

    assert_equal({ 'limit' => :integer }, operation.validate(limit: 'x').errors.symbolic)
    assert_equal({ 'limit' => :too_big }, operation.validate(limit: 9).errors.symbolic)
  end

  def test_sb_03_26_requires_one_of_wants_exactly_one_input
    operation = declare do
      optional do
        string :card
        string :account
      end

      requires_one_of :card, :account

      def execute
        [card, account].compact.first
      end
    end

    assert_equal 'c', operation.call(card: 'c')
    assert_equal({ 'base' => :requires_one_of }, operation.validate.errors.symbolic)
    assert_equal({ 'base' => :requires_one_of },
                 operation.validate(card: 'c', account: 'a').errors.symbolic)
    assert_match(/card/, operation.validate.errors.message_list.first)
  end

  def test_sb_03_26_requires_one_of_checks_its_names
    assert_raises(ServiceBroker::DeclarationError) do
      declare do
        optional { string :card }

        requires_one_of :card, :unknown_name
      end
    end
    assert_raises(ServiceBroker::DeclarationError) do
      declare do
        optional { string :card }

        requires_one_of :card
      end
    end
  end

  def test_sb_03_27_type_errors_come_before_the_rules
    operation = declare do
      optional do
        integer :card
        string :account
      end

      requires_one_of :card, :account
    end

    assert_equal({ 'card' => :integer }, operation.validate(card: 'x', account: 'a').errors.symbolic)
  end
end
