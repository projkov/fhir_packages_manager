# FHIR Packages Manager 

[![Gem Version](https://badge.fury.io/rb/fhir_packages_manager.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/fhir_packages_manager)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-CC342D?logo=ruby&logoColor=white)](fhir_packages_manager.gemspec)
[![codecov](https://codecov.io/gh/projkov/fhir_packages_manager/graph/badge.svg)](https://codecov.io/gh/projkov/fhir_packages_manager)
[![docs](https://img.shields.io/badge/docs-yard-blue.svg)](https://projkov.github.io/fhir_packages_manager/)

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

### Docker

The CLI is also published as a container image, so it can be used without installing Ruby
or the gem locally:

```bash
docker run --rm ghcr.io/projkov/fhir_packages_manager check hl7.fhir.us.core@6.1.0 -r https://packages.fhir.org

docker run --rm -v "$(pwd)/fhir_packages:/fhir_packages" ghcr.io/projkov/fhir_packages_manager \
  fetch hl7.fhir.us.core@6.1.0 -r https://packages.fhir.org -d /fhir_packages
```

Mount a volume (as above) to get downloaded `.tgz` files back out onto the host.

#### Docker Compose

A `docker-compose.yml` is included so the image name and volume mount don't need to be
retyped for every invocation:

```yaml
services:
  fhir_packages_manager:
    image: ghcr.io/projkov/fhir_packages_manager:latest
    build: .
    volumes:
      - ./fhir_packages:/fhir_packages
      # - ./fhir_packages_ignore.yml:/fhir_packages_ignore.yml:ro
```

Since the image's `ENTRYPOINT` is the CLI itself, anything passed after the service name
becomes its arguments:

```bash
docker compose run --rm fhir_packages_manager \
  check hl7.fhir.us.core@6.1.0 -r https://packages.fhir.org

docker compose run --rm fhir_packages_manager \
  fetch hl7.fhir.us.core@6.1.0 -r https://packages.fhir.org -d /fhir_packages
```

`docker compose run --rm` (rather than `up`) is used because this is a one-shot CLI, not a
long-running service — `--rm` discards the container after it exits. `docker compose pull`
fetches the published image from GHCR; `docker compose build` builds it locally from the
`Dockerfile` instead (e.g. to test an unreleased change). Uncomment the ignore-file volume
line and add `-i /fhir_packages_ignore.yml` to the command to use an ignore list.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

To release a new version: bump `VERSION` in `lib/fhir_packages_manager/version.rb`, add a
dated entry to `CHANGELOG.md`, and merge to `main`. Then either publish a GitHub Release (tag
`vX.Y.Z`) or manually run the `Release` workflow from the Actions tab — `.github/workflows/release.yml`
re-runs the full test/quality gate and, if it passes, publishes the gem to
[rubygems.org](https://rubygems.org) via Trusted Publishing and pushes the Docker image to
GHCR. Don't run `bundle exec rake release` locally — it would try to push using local
credentials instead of through that pipeline.

### Tests and code quality

`bundle exec rake` runs the full suite: RSpec (with a SimpleCov gate requiring 95%+ line
coverage), RuboCop, Reek, Fasterer, Flay, Flog, and Steep. Each is also runnable on its own,
e.g. `bundle exec rspec`, `bundle exec rake rubocop`, `bundle exec rake steep`.

RSpec specs stub all HTTP calls with WebMock (see `spec/fhir_packages_manager/registry_spec.rb`
and `cli_spec.rb`), so the suite never hits a real registry.

### Documentation

API docs are generated from the code with [YARD](https://yardoc.org) and published to
[GitHub Pages](https://projkov.github.io/fhir_packages_manager/) by
`.github/workflows/docs.yml` on every push to `main`. To build and browse them locally:

```bash
bundle exec yard doc   # writes HTML to doc/
bundle exec yard server --reload  # serves it at http://localhost:8808, rebuilding on change
```

`bundle exec yard stats --list-undoc` lists any undocumented public classes/methods.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/projkov/fhir_packages_manager. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/projkov/fhir_packages_manager/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the FhirPackagesManager project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/projkov/fhir_packages_manager/blob/main/CODE_OF_CONDUCT.md).
