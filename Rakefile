require 'rake/testtask'

Rake::TestTask.new(:core) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/core/**/*_test.rb']
  t.warning = false
end

Rake::TestTask.new(:meta) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/meta/**/*_test.rb']
  t.warning = false
end

# The Rails part loads ActiveRecord, so it runs in its own process.
Rake::TestTask.new(:rails) do |t|
  t.libs << 'test'
  t.libs << 'test/rails'
  t.libs << 'lib'
  t.test_files = FileList['test/rails/**/*_test.rb']
  t.warning = false
end

desc 'Run every suite, each in its own process'
task test: %i[core meta rails]

namespace :specs do
  desc 'Match requirement ids from specs with test method names'
  task :coverage do
    ruby '-Ilib -Itest test/meta/specs_coverage_test.rb'
  end
end

task default: :test
