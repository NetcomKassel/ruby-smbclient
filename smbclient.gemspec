# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'smbclient/version'

Gem::Specification.new do |spec|
  spec.name = 'smbclient'
  spec.version = SMBClient::VERSION
  spec.authors = ['Ralf Herzog']
  spec.email = ['ralf.herzog@netcom-kassel.de']

  spec.summary = %q(smbclient wrapper)
  spec.description = %q(Wrapper fuer smbclient)
  spec.homepage = 'https://netcom-kassel.de'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) do |f|
    File.basename f
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'globalog', '~> 0.1'
  spec.add_dependency 'abundance', '~> 1.3'
  spec.add_dependency 'ftools', '~> 0.0'

  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'simplecov', '~> 0.14.1'
end
