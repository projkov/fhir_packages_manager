# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development process

A feature or change isn't done until all three of these hold — this is the same bar
`quality.yml` enforces on every push, so run `bundle exec rake` locally before pushing:

1. **Covered by tests.** Add specs in `spec/fhir_packages_manager/` for the new behavior,
   including its failure modes, not just enough to keep the coverage gate green. Run
   `bundle exec rspec` and confirm the SimpleCov gate still passes (see "Running tests" below).
2. **Documented.** Any new or changed public class/method gets YARD `@param`/`@return`/`@raise`
   docs (see "Docs" below). If it changes user-facing behavior, also update `README.md` and add
   an entry to `CHANGELOG.md`.
3. **Clean against all code quality tools.** `bundle exec rake` (spec + rubocop + reek +
   fasterer + flay + flog + steep) must exit 0. If a tool complains, prefer fixing the code; only
   tune `.rubocop.yml`/`.reek.yml` for a genuine false positive on this codebase's style, and say
   why inline (see the existing entries in those files for the bar to clear).

## Commands

Install dependencies: `bin/setup` (or `bundle install`).

### Running tests

```bash
bundle exec rspec                              # full suite
bundle exec rspec spec/fhir_packages_manager/registry_spec.rb   # one file
bundle exec rspec spec/fhir_packages_manager/registry_spec.rb:42  # one example, by line
bundle exec rspec -e "returns nil when the version does not exist"  # by description
```

SimpleCov enforces a **95% minimum line coverage** gate (see `spec/spec_helper.rb`) — `rspec`
exits non-zero if coverage drops below it, independent of test pass/fail. Branch coverage is
also tracked (currently 100%) but not gated. All HTTP is stubbed with WebMock
(`WebMock.disable_net_connect!` in `spec_helper.rb`); the suite never hits a real registry.

### Code quality

```bash
bundle exec rake            # default task: spec, rubocop, reek, fasterer, flay, flog, steep — everything
bundle exec rake rubocop    # or reek / fasterer / flay / flog / steep individually
bundle exec rubocop -A      # autocorrect (safe + unsafe); rubocop alone has no rake wrapper for this
bundle exec steep check     # type-check lib/ against sig/**/*.rbs
```

All six tools must pass cleanly (0 offenses/warnings) — this is enforced in CI on every push.
Tuned deviations from each tool's defaults, and *why*, are documented inline in `.rubocop.yml`
and `.reek.yml`; read those before assuming a cop/detector should just be silenced.

### Docs

```bash
bundle exec yard doc                  # writes HTML to doc/
bundle exec yard server --reload      # serve locally at :8808
bundle exec yard stats --list-undoc   # check for undocumented public API
```

Every public class/method has YARD docs (`@param`/`@return`/`@raise`); this is enforced by
convention, not a tool gate, so keep new public API documented.

### Docker

```bash
docker build -t fhir_packages_manager .
docker compose run --rm fhir_packages_manager check hl7.fhir.us.core@6.1.0 -r https://packages.fhir.org
```

## Architecture

This is a Ruby gem (`FhirPackagesManager`) that resolves and downloads FHIR implementation
guide packages from npm-style registries, plus a CLI (`exe/fhir_packages_manager`) and a
Docker image wrapping the same CLI. There is no runtime dependency beyond Ruby stdlib
(`net/http`, `uri`, `json`, `yaml`, `optparse`, `fileutils`).

### Core object flow

`Manager` is the top-level orchestrator; everything else is a collaborator it drives:

- **`Registry`** — a client for one registry base URL (e.g. `packages.fhir.org`). Talks raw
  `Net::HTTP` (no gem dependency). All requests funnel through the private `request`/`follow`
  pair in `registry.rb`, which handles redirect-following, non-HTTP-scheme rejection, and
  missing-host/missing-Location-header cases — read that pair together, not in isolation, when
  touching HTTP behavior. `metadata(name)` is memoized per-instance in `@metadata_cache`.
- **`Package`** — a `Struct.new(:name, :version)` subclass (declared as `class Package <
  Struct.new(...)`, *not* `Package = Struct.new(...) do ... end` — the latter breaks Steep's
  ability to resolve `self` inside the block; `Style/StructInheritance` is disabled in
  `.rubocop.yml` specifically to allow this). `Package.parse("name@version")` is the one
  parsing entry point; a bare name means "resolve to latest".
- **`IgnoreList`** — loaded from YAML/JSON (`.load`), a flat array of bare names (ignore every
  version) or `{name:, version:}` hashes (ignore one version).
- **`Manager#fetch`** ties these together: parse → check `IgnoreList` → `find_registry` (tries
  each `Registry` in order, first match wins) → download → wrap outcome in **`FetchResult`**
  (`:downloaded` / `:ignored` / `:not_found` / `:error`, the last carrying an `HttpError`
  message). `fetch` itself never raises for expected failure modes — everything expected
  surfaces as a `FetchResult` status.
- **`Manager#list_versions(name)`** / **`Registry#versions(name)`** — lists every version across
  all configured registries (`{registry_base_url => [versions]}`), filtering ignored
  versions/packages the same way `fetch` does. Unlike `fetch`, this does **not** wrap errors:
  a registry not having the package (`PackageNotFoundError`) is swallowed and just excluded from
  the result, but any other `HttpError` propagates uncaught — this mirrors `find_registry`'s/
  `version?`'s existing "not found" is the only expected failure convention, so keep that
  parity if you touch either.
- **`Manager#sync(name)`** — the delta of `list_versions` against what's already on disk: builds
  candidate versions from `Registry#versions` **unfiltered** by the ignore list (unlike
  `list_versions`), then per version either short-circuits to a `:skipped` `FetchResult` if
  `name-version.tgz` already exists in `destination`, or calls `#fetch` on it — so an individual
  ignored version still surfaces as the normal `:ignored` result (via `fetch`'s own check), while
  a whole-package ignore short-circuits to one `:ignored` result without querying any registry.
  This is why `sync` doesn't reuse `list_versions` for enumeration despite the surface-level
  similarity — reusing it would silently drop ignored versions instead of reporting them.
  `download_path`/`download_result`/`sync_version` all take a `Package`, not separate
  `name`/`version` args — Reek's `DataClump` flagged the primitive-pair version of this, and
  since `Package` already exists for exactly this, that was the right fix over tuning the cop.
- **`CLI`** is a thin wrapper: parses argv with `OptionParser`, builds a `Manager`, and prints
  one line per result. `check`/`list` call `Manager#find_registry`/`#list_versions` directly
  instead of fetching, so an uncaught `HttpError` from either crashes the CLI with a raw
  backtrace (intentional/existing behavior, not a regression); `sync` instead reuses `fetch_line`
  and inherits `fetch`'s per-item error handling, so a download failure surfaces as an `ERR` line
  rather than crashing. `exe/fhir_packages_manager` itself is a 3-line shebang script that requires
  outside `lib/`'s `.rb` glob so quality tools would otherwise miss it if logic lived there.

### The gemspec's file list is git-driven — new top-level tooling files must be excluded

`fhir_packages_manager.gemspec` computes `spec.files` via `git ls-files`, then rejects a
hardcoded list of prefixes (`bin/`, `spec/`, `.github/`, `Dockerfile`, `.rubocop.yml`, etc.) so
none of the CI/dev tooling ships inside the built gem. **Any new top-level config/tooling file
you add must be added to that rejection list**, or it will silently get packaged into the gem.
Verify with `gem build fhir_packages_manager.gemspec -o /tmp/test.gem && gem specification
/tmp/test.gem files` after adding new root-level files.

### CI/CD (four independent GitHub Actions workflows)

- **`quality.yml`** — `bundle exec rake` on every push to every branch; uploads coverage to
  Codecov.
- **`release.yml`** — triggered by a published GitHub Release *or* manual `workflow_dispatch`.
  Re-runs the full quality gate (`needs: test`), then in parallel: publishes to RubyGems.org
  via **Trusted Publishing** (OIDC, `rubygems/release-gem` action, no stored API key) and
  builds/pushes the Docker image to GHCR (`ghcr.io/projkov/fhir_packages_manager`, tagged
  `latest` + the version read live from `FhirPackagesManager::VERSION`, for both `linux/amd64`
  and `linux/arm64` via `docker/setup-qemu-action` + `platforms:` on the build-push step — a
  single-arch build here is what caused "no matching manifest" pulling on Apple Silicon).
  Bumping `lib/fhir_packages_manager/version.rb` is a prerequisite for a real release —
  RubyGems rejects re-pushing an existing version, so this fails loudly (not silently) if
  forgotten. This supersedes the generic `bundle exec rake release` task that
  `bundler/gem_tasks` still provides — don't use that locally, since it would try to push with
  local credentials instead of through the CI trusted-publishing path.
- **`docker-snapshot.yml`** — manual `workflow_dispatch` only. Same test gate and multi-arch
  build as `release.yml`'s docker job, but tags
  `ghcr.io/projkov/fhir_packages_manager:<gem-version>-<short-sha>` (e.g. `0.1.0-9649122`) and
  never `latest` — lets you get a fresh image from an unreleased commit without bumping
  `VERSION` or cutting a RubyGems release.
- **`docs.yml`** — on push to `main`, generates YARD docs and deploys them to GitHub Pages via
  the standard `actions/configure-pages` → `upload-pages-artifact` → `deploy-pages` flow.

### RBS/Steep

`sig/` mirrors `lib/`'s structure file-for-file. `Steepfile` targets `lib` with `library`
declarations for the stdlib pieces above (resolved from RBS's bundled core signatures, no `rbs
collection` needed). When changing a public method's signature in `lib/`, update the matching
`.rbs` file in the same commit — `steep check` (part of `rake`) will catch drift as a type
error, not a warning.
