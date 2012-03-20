# -*- encoding: utf-8 -*-
require File.expand_path('../lib/logmixer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Noah Zoschke"]
  gem.email         = ["noah@heroku.com"]
  gem.description   = %q{Stateless log parsing, routing, filtering and analysis}
  gem.summary       = %q{}
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "logmixer"
  gem.require_paths = ["lib"]
  gem.version       = Logmixer::VERSION
end
