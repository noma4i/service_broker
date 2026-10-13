require 'test_helper'

class GemspecTest < BrokerTest
  def spec
    @spec ||= Gem::Specification.load(File.expand_path('../../service_broker.gemspec', __dir__))
  end

  def test_sb_01_04_declares_three_runtime_dependencies
    names = spec.dependencies.select { |dep| dep.type == :runtime }.map(&:name).sort

    assert_equal %w[activejob activerecord activesupport], names
  end

  def test_sb_01_04_declares_no_other_runtime_dependency
    forbidden = %w[sentry-ruby faraday hashie good_job sidekiq]
    names = spec.dependencies.map(&:name)

    assert_empty names & forbidden
  end

  def test_sb_01_05_requires_ruby_3_2_and_rails_7_0
    assert spec.required_ruby_version.satisfied_by?(Gem::Version.new('3.2.0'))
    refute spec.required_ruby_version.satisfied_by?(Gem::Version.new('3.1.9'))

    spec.dependencies.select { |dep| dep.type == :runtime }.each do |dep|
      assert dep.requirement.satisfied_by?(Gem::Version.new('7.0.0')), dep.name
      refute dep.requirement.satisfied_by?(Gem::Version.new('6.1.0')), dep.name
    end
  end
end
