# FhirPackagesManager

Checks the availability of FHIR implementation guide packages against npm-style
registries (e.g. `packages.fhir.org`, `packages.simplifier.net`), skips any
packages/versions on a configurable ignore list, and downloads the resulting
`.tgz` tarballs into a destination folder.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add fhir_packages_manager
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install fhir_packages_manager
```

## Usage

### Library

```ruby
require "fhir_packages_manager"

manager = FhirPackagesManager::Manager.new(
  registries: ["https://packages.fhir.org", "https://packages.simplifier.net"],
  destination: "./fhir_packages",
  ignore_list: FhirPackagesManager::IgnoreList.load("fhir_packages_ignore.yml") # optional
)

manager.available?("hl7.fhir.us.core", "6.1.0") # => true/false

result = manager.fetch("hl7.fhir.us.core@6.1.0")
result.status # => :downloaded, :ignored, :not_found, or :error
result.path   # => "./fhir_packages/hl7.fhir.us.core-6.1.0.tgz" when downloaded

manager.fetch_all(["hl7.fhir.us.core@6.1.0", "hl7.fhir.r4.core"]) # bare name = latest
```

The ignore list file (YAML or JSON) is a flat array where a bare string
ignores every version of a package, and a hash pins a single version:

```yaml
- hl7.fhir.r4.core
- name: hl7.fhir.us.core
  version: 3.1.0
```

### CLI

```bash
exe/fhir_packages_manager check hl7.fhir.us.core@6.1.0 -r https://packages.fhir.org
exe/fhir_packages_manager fetch hl7.fhir.us.core@6.1.0 hl7.fhir.r4.core \
  -r https://packages.fhir.org -r https://packages.simplifier.net \
  -d ./fhir_packages -i fhir_packages_ignore.yml
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/prozskov/fhir_packages_manager. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/prozskov/fhir_packages_manager/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the FhirPackagesManager project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/prozskov/fhir_packages_manager/blob/main/CODE_OF_CONDUCT.md).
