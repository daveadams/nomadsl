require_relative 'lib/nomadsl/version.rb'

Gem::Specification.new do |s|
  s.name = 'nomadsl'
  s.version = Nomadsl::VERSION
  s.authors = ['David Adams']
  s.email = 'daveadams@gmail.com'
  s.date = Time.now.strftime('%Y-%m-%d')
  s.license = 'CC0'
  s.homepage = 'https://github.com/daveadams/nomadsl'
  s.required_ruby_version = '>=2.4.0'

  s.summary = 'Ruby DSL for generating Nomad job specification files'

  s.require_paths = ['lib']
  s.files = Dir["lib/**/*.rb"] + [
    'README.md',
    'LICENSE',
    'nomadsl.gemspec'
  ]
end
