lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'resque-cluster/version'

Gem::Specification.new do |s|
  s.name        = 'resque-cluster'
  s.version     = Resque::Cluster::VERSION
  s.date        = '2015-07-23'
  s.summary     = %q{Creates and manages resque worker in a distributed cluster}
  s.description = %q{A management tool for resque workers. Allows spinning up and managing resque workers across multiple machines sharing the same Redis server}
  s.authors     = ["Yasha Portnoy"]
  s.email       = 'yash.portnoy@gmail.com'
  s.homepage    = 'https://github.com/yportnoy/resque-cluster'
  s.license     = 'MIT'

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_dependency  'resque-pool', '~> 0.5.0'
  s.add_dependency  'gru', '0.0.3'

  s.add_development_dependency 'pry', '> 0.0'
  s.add_development_dependency 'awesome_print', '> 0.0'
  s.add_development_dependency 'rspec', '~> 3.1.0'
  s.add_development_dependency 'rdoc', '~> 3.12'
  s.add_development_dependency 'bundler', '~> 1.7'
  s.add_development_dependency 'jeweler', '~> 2.0.1'
  s.add_development_dependency 'simplecov', '>= 0'
  s.add_development_dependency 'rubocop', '~> 0.31'
  s.add_development_dependency 'mock_redis', '~> 0.15.0'
end
