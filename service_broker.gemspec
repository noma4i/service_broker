require_relative 'lib/service_broker/version'

Gem::Specification.new do |spec|
  spec.name = 'service_broker'
  spec.version = ServiceBroker::VERSION
  spec.authors = ['noma4i']
  spec.summary = 'Application operations with declared inputs, checked values and one entry point'
  spec.description = 'ServiceBroker::Operation declares inputs, checks values, runs execute and ' \
                     'returns a result or a set of errors. Deferred calls go through a replaceable runner.'
  spec.homepage = 'https://github.com/noma4i/service_broker'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*', 'README.md', 'CHANGELOG.md', 'LICENSE']
  spec.require_paths = ['lib']

  spec.add_dependency 'activejob', '>= 7.0'
  spec.add_dependency 'activerecord', '>= 7.0'
  spec.add_dependency 'activesupport', '>= 7.0'
end
