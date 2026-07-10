# syntax=docker/dockerfile:1

# Builder stage: needs git + the .git dir because the gemspec lists packaged
# files via `git ls-files` (see fhir_packages_manager.gemspec).
FROM ruby:3.3-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN gem build fhir_packages_manager.gemspec -o fhir_packages_manager.gem

# Final stage: just the installed gem, no source tree, no git.
FROM ruby:3.3-slim

COPY --from=builder /app/fhir_packages_manager.gem /tmp/fhir_packages_manager.gem
RUN gem install /tmp/fhir_packages_manager.gem --no-document \
    && rm /tmp/fhir_packages_manager.gem

ENTRYPOINT ["fhir_packages_manager"]
