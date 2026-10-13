require 'test_helper'

class OperationFormTest < BrokerTest
  def test_sb_02_01_operation_without_the_base_has_no_entry_point
    plain = Class.new do
      def execute
        :done
      end
    end

    assert_raises(NoMethodError) { plain.call(name: 'a') }
  end

  def test_sb_02_01_sync_operation_is_an_operation
    assert_operator ServiceBroker::SyncOperation, :<, ServiceBroker::Operation
  end

  def test_sb_02_02_compact_declaration_resolves_sibling_constants
    assert_equal 'Probe::Media::BuildThumbnail', Probe::Media::BuildThumbnail.name
    assert_equal 640, Probe::Media::BuildThumbnail.call(width: 320)
  end

  def test_sb_02_04_one_operation_class_per_file
    probe_files = Dir[File.expand_path('../support/probe/*.rb', __dir__)] +
                  Dir[File.expand_path('../rails/support/probe/*.rb', __dir__)]
    counts = probe_files.to_h do |file|
      [file, File.read(file).scan(/^class \S+ < (?:ServiceBroker|Probe)\S*(?:Operation|Base)/).size]
    end

    refute_empty counts
    crowded = counts.select { |_file, count| count > 1 }

    assert_empty crowded, "files with 2 or more operations: #{crowded.keys.join(', ')}"
  end

  def test_sb_02_13_family_base_runs_no_branch_per_subclass
    base = declare do
      abstract_methods :payload

      def execute
        [:base, payload]
      end
    end
    first = declare(base) do
      private

      def payload
        :first
      end
    end
    second = declare(base) do
      private

      def payload
        :second
      end
    end

    assert_equal %i[base first], first.call
    assert_equal %i[base second], second.call
  end

  def test_sb_02_05_public_methods_are_execute_and_input_accessors
    operation = declare do
      required { string :title }

      def execute
        title
      end
    end

    assert_equal %i[execute title title= title_present?].sort,
                 operation.public_instance_methods(false).sort
  end

  def test_sb_02_06_operation_cannot_declare_its_own_entry_point
    error = assert_raises(ServiceBroker::DeclarationError) do
      declare do
        def self.call(**)
          :own
        end
      end
    end

    assert_match(/call/, error.message)
  end

  def test_sb_02_07_operation_cannot_declare_initialize
    error = assert_raises(ServiceBroker::DeclarationError) do
      declare do
        def initialize(*)
          super
        end
      end
    end

    assert_match(/initialize/, error.message)
  end

  def test_sb_02_08_helper_methods_stay_private
    operation = declare do
      required { string :title }

      def execute
        shout
      end

      private

      def shout
        title.upcase
      end
    end

    assert_includes operation.private_instance_methods(false), :shout
    assert_empty operation.protected_instance_methods(false)
    assert_equal 'AB', operation.call(title: 'ab')
  end

  def test_sb_02_11_family_base_shares_inputs
    base = declare do
      required { string :title }
    end
    child = declare(base) do
      required { integer :size }

      def execute
        [title, size]
      end
    end

    assert_equal %i[title], base.input_names
    assert_equal %i[title size], child.input_names
    assert_equal ['ab', 2], child.call(title: 'ab', size: 2)
  end

  def test_sb_02_12_child_does_not_change_the_base_declaration
    base = declare do
      required { string :title }
    end
    declare(base) do
      required { integer :title }
    end

    assert_equal :string, base.input_type(:title)
  end

  def test_sb_02_12_child_can_redeclare_an_inherited_input
    base = declare do
      required { string :code }
    end
    child = declare(base) do
      required { integer :code }

      def execute
        code
      end
    end

    assert_equal 5, child.call(code: '5')
    assert_equal :integer, child.input_type(:code)
  end

  def test_sb_02_14_operation_declares_no_alias_of_the_entry_point
    sources = Dir[File.expand_path('../../lib/service_broker/**/*.rb', __dir__)]
              .map { |file| File.read(file) }.join("\n")

    refute_match(/alias(_method)?\s+:?call/, sources)
  end
end
