# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'avalon-batch/version'

Gem::Specification.new do |gem|
  gem.name          = "avalon-batch"
  gem.version       = Avalon::Batch::VERSION
  gem.authors       = ["Michael B. Klein"]
  gem.email         = ["mbklein@gmail.com"]
  gem.description   = %q{Batch ingest tools for Avalon}
  gem.summary       = %q{Batch ingest tools for Avalon}

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'roo'
  gem.add_dependency 'activesupport'
  gem.add_development_dependency 'pry'
end
