# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-07-10

### Added

- `sync` CLI command and `Manager#sync`: downloads every non-ignored version of a package not
  already present in the destination folder (checked as `name-version.tgz`, the same naming
  `fetch` uses), reusing `#fetch` for the actual download of each missing version. Output reuses
  `fetch`'s `OK`/`SKIP`/`MISS`/`ERR` lines, with `SKIP` covering both an ignored version and one
  already on disk. (#3)

## [0.2.0] - 2026-07-10

### Added

- `list` CLI command and `Manager#list_versions`/`Registry#versions`: lists every version of a
  package published across all configured registries, without needing a version suffix on the
  spec. Respects the ignore list the same way `fetch` does (whole-package or single-version
  entries). (#1)

## [0.1.0] - 2026-07-10

### Added

- **Library**: `FhirPackagesManager::Manager`, `Registry`, `Package`, `IgnoreList`, and
  `FetchResult`, providing:
  - Availability checks and version resolution (including `latest`) against one or more
    npm-style FHIR package registries (e.g. `packages.fhir.org`, `packages.simplifier.net`),
    tried in the order given.
  - A configurable ignore list (loaded from YAML or JSON) that skips a package entirely or
    pins a single ignored version.
  - Tarball download into a destination folder, with `HttpError`/`PackageNotFoundError` for
    failure cases and a `:downloaded`/`:ignored`/`:not_found`/`:error` result per package.
- **CLI**: `fhir_packages_manager` executable with `check` and `fetch` subcommands
  (`-r/--registry`, `-d/--destination`, `-i/--ignore-file`, repeatable `--registry`).
- **Docker**: a multi-stage `Dockerfile` that builds and installs the gem from source and
  exposes the CLI as the image's entrypoint, plus a `docker-compose.yml` for running it
  without a local Ruby install.
- **Tests**: an RSpec suite (HTTP stubbed with WebMock, so it never hits a real registry)
  covering the library, CLI, and every registry edge case (redirects, missing `Location`
  header, unsupported URL schemes, 404s, etc.), with 100% line and branch coverage enforced
  by a SimpleCov minimum-coverage gate.
- **Code quality tooling**: RuboCop, Reek, Fasterer, Flay, Flog, and Steep (with full RBS
  signatures for every class), all wired into `bundle exec rake`.
- **CI/CD** (GitHub Actions):
  - `quality.yml` — runs the full test/quality suite on every push to any branch, uploading
    coverage to Codecov.
  - `release.yml` — on a published GitHub Release or manual dispatch, re-runs the test/quality
    gate, then publishes the gem to RubyGems.org (via Trusted Publishing) and the Docker image
    to GitHub Container Registry.
  - `docs.yml` — publishes YARD API documentation to GitHub Pages on every push to `main`.
- **Documentation**: YARD doc comments across the public API, and a Codecov/docs badge pair
  in the README.

[Unreleased]: https://github.com/projkov/fhir_packages_manager/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/projkov/fhir_packages_manager/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/projkov/fhir_packages_manager/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/projkov/fhir_packages_manager/releases/tag/v0.1.0
