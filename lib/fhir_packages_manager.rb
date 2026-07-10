# frozen_string_literal: true

require_relative 'fhir_packages_manager/version'
require_relative 'fhir_packages_manager/errors'
require_relative 'fhir_packages_manager/package'
require_relative 'fhir_packages_manager/fetch_result'
require_relative 'fhir_packages_manager/registry'
require_relative 'fhir_packages_manager/ignore_list'
require_relative 'fhir_packages_manager/manager'

# Checks the availability of FHIR implementation guide packages against
# npm-style registries (e.g. packages.fhir.org, packages.simplifier.net),
# skips entries on a configurable {IgnoreList}, and downloads the resulting
# tarballs via {Manager}. See the README for usage examples.
module FhirPackagesManager
end
