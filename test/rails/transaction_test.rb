require 'rails_helper'

class TransactionTest < RailsBrokerTest
  def writing_operation
    declare do
      required { string :title }

      def execute
        ::Probe::Account.create!(title: title)
        raise ArgumentError, 'boom'
      end
    end
  end

  def test_sb_08_13_safe_rolls_back_the_write
    assert_raises(ArgumentError) { writing_operation.call(title: 'a', safe: true) }

    assert_equal 0, Probe::Account.count
  end

  def test_sb_08_13_without_safe_the_write_stays
    assert_raises(ArgumentError) { writing_operation.call(title: 'a') }

    assert_equal 1, Probe::Account.count
  end

  def test_sb_05_10_transaction_covers_input_checking_and_validate
    operation = declare do
      required { string :title }

      def execute
        :done
      end

      private

      def validate
        ::Probe::Account.create!(title: title)
        add_error(:title, :rejected)
      end
    end

    outcome = operation.call(title: 'a', safe: true, soft: true)

    refute outcome.success?
    assert_equal 0, Probe::Account.count
  end

  def test_sb_05_11_rollback_returns_no_result
    operation = declare do
      def execute
        ::Probe::Account.create!(title: 'a')
        raise ActiveRecord::Rollback
      end
    end

    assert_nil operation.call(safe: true)
    assert_equal 0, Probe::Account.count
  end

  def test_sb_08_14_nested_safe_rolls_back_only_its_own_rows
    inner = declare do
      def execute
        ::Probe::Account.create!(title: 'inner')
        throw_error(:nope, 'inner refuses')
      end
    end
    outer = declare do
      define_method(:execute) do
        ::Probe::Account.create!(title: 'outer')
        inner.call(safe: true, soft: true)
      end
    end

    outer.call(safe: true)

    assert_equal ['outer'], Probe::Account.pluck(:title)
  end
end
