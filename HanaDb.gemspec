require_relative 'lib/HanaDb/version'

Gem::Specification.new do |spec|
  spec.name          = "HanaDb"
  spec.version       = HanaDb::VERSION
  spec.authors       = ["Avdhesh"]
  spec.email         = ["avdhesh51000@gmail.com"]

  spec.summary       = %q{Active record hana_adapter.}
  spec.description   = %q{Active record hanaclient adapter to connect with hana db.}
  spec.homepage      = "https://github.com/Avdhesh51000/HanaDb"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

    spec.metadata["allowed_push_host"] = "https://rubygems.org/"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/Avdhesh51000/HanaDb"
    # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.add_development_dependency 'rails'
  spec.add_development_dependency 'hanaclient'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
