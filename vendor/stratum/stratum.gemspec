# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "stratum"
  spec.version       = "0.1.0"
  spec.authors       = ["TAGOMORI Satoshi"]
  spec.email         = ["tagomoris@gmail.com"]
  spec.summary       = %q{O/R Mapper for MySQL with data versionings}
  spec.description   = %q{O/R Matter for MySQL with data versionings}
  spec.homepage      = "https://github.com/tagomoris/stratum"
  spec.license       = "APLv2"

  spec.files         = Dir.chdir(__dir__) { Dir['lib/**/*.rb'] + ['README.md'] }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.3", "< 3.4"

  spec.add_runtime_dependency "mysql2", "~> 0.5.6"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rake"
end
