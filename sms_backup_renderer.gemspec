# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sms_backup_renderer/version'

Gem::Specification.new do |spec|
  spec.name          = "sms_backup_renderer"
  spec.version       = SmsBackupRenderer::VERSION
  spec.authors       = ["Jacob Williams"]
  spec.email         = ["jacobaw@gmail.com"]

  spec.summary       = %q{Generates static HTML pages for the contents of an SMS Backup & Restore archive.}
  spec.homepage      = "https://github.com/brokensandals/sms_backup_renderer"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(docs|test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'nokogiri', '~> 1.8'
  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency 'rspec', '~> 3.6'
end
