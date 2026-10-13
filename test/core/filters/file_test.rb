require 'test_helper'

class FileFilterTest < BrokerTest
  def operation(**)
    declare do
      required { file(:value, **) }

      def execute
        value
      end
    end
  end

  def code(input, **)
    operation(**).validate(value: input).errors.symbolic['value']
  end

  def upload(body)
    file = StringIO.new(body)
    file.define_singleton_method(:original_filename) { 'a.txt' }
    file.define_singleton_method(:content_type) { 'text/plain' }
    file
  end

  def test_sb_04_30_requires_read_size_and_the_upload_methods
    assert_equal :file, code(Object.new)
    assert_kind_of StringIO, operation.call(value: StringIO.new('abc'))
    assert_equal :file, code(StringIO.new('abc'), upload: true)
    assert_kind_of StringIO, operation(upload: true).call(value: upload('abc'))
    assert_equal :size, code(StringIO.new('abc'), size: 2)
  end

  def test_sb_04_30_checking_does_not_read_the_file
    file = StringIO.new('abc')
    operation.call(value: file)

    assert_equal 0, file.pos
  end

  def test_sb_04_31_codes_and_default_options
    assert_equal %i[nils size upload], ServiceBroker::Filters::File.default_options.keys.sort
    assert_equal :nils, code(nil)
    assert_equal :empty, code('')
  end
end
