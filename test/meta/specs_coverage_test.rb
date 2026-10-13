require 'test_helper'

class SpecsCoverageTest < BrokerTest
  ROOT = File.expand_path('../..', __dir__)
  SPECS = File.join(ROOT, 'specs')
  APPLICATION_SECTION = '11'.freeze

  def requirements
    @requirements ||= Dir[File.join(SPECS, '[0-9]*.md')].flat_map do |file|
      File.readlines(file).filter_map do |line|
        line[/^### (SB-\d\d-\d\d)/, 1]
      end
    end
  end

  def test_names
    @test_names ||= Dir[File.join(ROOT, 'test/**/*_test.rb')].flat_map do |file|
      File.read(file).scan(/def (test_sb_\d\d_\d\d)\w*/).flatten
    end
  end

  def covered
    test_names.map { |name| name[/test_sb_(\d\d)_(\d\d)/, 0].sub('test_sb_', 'SB-').sub('_', '-') }
  end

  def test_sb_10_03_every_requirement_has_a_test
    expected = requirements.reject { |id| id.start_with?("SB-#{APPLICATION_SECTION}") }
    missing = expected - covered

    assert_empty missing, "requirements without a test: #{missing.join(', ')}"
  end

  def test_sb_10_03_every_test_names_a_known_requirement
    unknown = covered.uniq - requirements

    assert_empty unknown, "tests naming unknown requirements: #{unknown.join(', ')}"
  end

  def test_sb_10_03_requirement_ids_are_unique
    duplicates = requirements.tally.select { |_id, count| count > 1 }.keys

    assert_empty duplicates
  end

  def test_sb_10_05_no_requirement_has_more_than_three_tests
    crowded = covered.tally.select { |_id, count| count > 3 }

    assert_empty crowded, "split or merge these: #{crowded.keys.join(', ')}"
  end

  def test_sb_10_06_no_test_is_skipped
    sources = Dir[File.join(ROOT, 'test/**/*.rb')].map { |file| File.read(file) }.join("\n")

    refute_match(/^\s*skip\b/, sources)
  end

  def test_sb_10_07_probe_operations_live_in_support
    stray = Dir[File.join(ROOT, 'test/**/*_test.rb')].select do |file|
      File.read(file).match?(/^class Probe::/)
    end

    assert_empty stray
  end

  def test_sb_10_08_thread_rules_are_checked_with_threads
    %w[test/core/thread_safety_test.rb test/rails/active_job_async_test.rb].each do |path|
      body = File.read(File.join(ROOT, path))

      assert_includes body, 'Thread.new', path
      assert_includes body, 'join', path
    end
  end

  def test_sb_10_01_core_tests_need_no_rails
    sources = Dir[File.join(ROOT, 'test/core/**/*_test.rb')].map { |file| File.read(file) }.join("\n")

    refute_match(/require ['"]rails_helper['"]/, sources)
    refute_match(/^\s*(ActiveRecord|ActiveJob)[.:]/, sources)
  end

  def test_sb_10_02_mutation_table_covers_every_spec_file
    table = File.read(File.join(ROOT, 'test/MUTATIONS.md'))
    files = Dir[File.join(SPECS, '[0-1][0-9]-*.md')].map { |file| File.basename(file) }
                                                    .reject { |file| file.start_with?(APPLICATION_SECTION) }

    missing = files.reject { |file| table.include?(file) }

    assert_empty missing, "spec files without a mutation row: #{missing.join(', ')}"
  end

  def test_sb_10_04_mutation_table_names_a_red_result_for_every_row
    rows = File.readlines(File.join(ROOT, 'test/MUTATIONS.md'))
               .grep(/^\| \d\d-/)
               .map { |line| line.split('|').map(&:strip).reject(&:empty?) }
               .select { |cells| cells.size == 4 }

    expected = Dir[File.join(SPECS, '[0-1][0-9]-*.md')]
               .map { |file| File.basename(file) }
               .reject { |file| file.start_with?(APPLICATION_SECTION) }

    assert_equal expected.size, rows.size
    rows.each { |cells| assert_match(/failures|errors/, cells[3], cells.inspect) }
  end
end
