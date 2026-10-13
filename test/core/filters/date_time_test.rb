require 'test_helper'

class DateTimeFiltersTest < BrokerTest
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

  def test_sb_04_23_both_types_share_their_options
    keys = %i[after before empty_is_nil format nils on_or_after on_or_before]

    %i[Date Time].each do |name|
      filter = ServiceBroker::Filters.const_get(name)

      assert_equal keys, filter.default_options.keys.sort, name.to_s
    end
  end

  def test_sb_04_24_date_input_becomes_a_date
    assert_instance_of ::Date, operation(:date).call(value: DateTime.now)
    assert_instance_of ::Date, operation(:date).call(value: ::Time.now)
    assert_equal ::Date.new(2026, 3, 1), operation(:date).call(value: '2026-03-01')
    assert_equal :date, code(:date, '31.02.2026')
  end

  def test_sb_04_24_date_format_option
    assert_equal ::Date.new(2026, 3, 1), operation(:date, format: '%d/%m/%Y').call(value: '01/03/2026')
    assert_equal :date, code(:date, '2026-03-01', format: '%d/%m/%Y')
  end

  def test_sb_04_25_time_input_becomes_a_time
    assert_instance_of ::Time, operation(:time).call(value: ::Date.today)
    assert_equal :time, code(:time, '25:00')
  end

  def test_sb_04_26_strict_and_inclusive_bounds
    today = ::Date.today

    assert_equal :after, code(:date, today, after: today)
    assert_equal today, operation(:date, on_or_after: today).call(value: today)
    assert_equal :before, code(:date, today, before: today)
    assert_equal today, operation(:date, on_or_before: today).call(value: today)
  end

  def test_sb_04_27_error_codes
    today = ::Date.today

    assert_equal :nils, code(:date, nil)
    assert_equal :empty, code(:date, '')
    assert_equal :date, code(:date, 'x')
    assert_equal :after, code(:date, today - 1, after: today)
    assert_equal :before, code(:date, today + 1, before: today)
    assert_equal :on_or_after, code(:date, today - 1, on_or_after: today)
    assert_equal :on_or_before, code(:date, today + 1, on_or_before: today)

    now = ::Time.now

    assert_equal :nils, code(:time, nil)
    assert_equal :empty, code(:time, '')
    assert_equal :time, code(:time, 'x')
    assert_equal :after, code(:time, now - 60, after: now)
    assert_equal :on_or_before, code(:time, now + 60, on_or_before: now)
  end
end
