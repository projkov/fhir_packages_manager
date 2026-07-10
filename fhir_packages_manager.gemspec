# frozen_string_literal: true

require_relative 'lib/fhir_packages_manager/version'

Gem::Specification.new do |spec|
  spec.name = 'fhir_packages_manager'
  spec.version = FhirPackagesManager::VERSION
  spec.authors = ['Pavel Rozhkov']
  spec.email = ['prozskov@gmail.com', 'pavel.r@beda.software']

  spec.summary = 'Check availability of and download FHIR packages from npm-style registries.'
  spec.description = 'Resolves FHIR implementation guide packages against registries such as ' \
                     'packages.fhir.org and packages.simplifier.net, skips entries on a ' \
                     'configurable ignore list, and downloads the resulting tarballs into a folder.'
  spec.homepage = 'https://github.com/projkov/fhir_packages_manager'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['documentation_uri'] = 'https://projkov.github.io/fhir_packages_manager/'
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ spec/ .github/ Gemfile Dockerfile docker-compose.yml .dockerignore
                          .gitignore .rspec .rubocop.yml .reek.yml .yardopts Steepfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
