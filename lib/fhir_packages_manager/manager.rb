# frozen_string_literal: true

require 'fileutils'

module FhirPackagesManager
  # Orchestrates checking availability across a set of registries, honoring an
  # ignore list, and downloading tarballs into a destination folder.
  class Manager
    # @return [Array<Registry>] registries checked, in the order given to {#initialize}
    attr_reader :registries
    # @return [String] the folder packages are downloaded into
    attr_reader :destination
    # @return [IgnoreList, nil] packages/versions skipped by {#fetch}
    attr_reader :ignore_list

    # @param registries [Array<String, Registry>] one or more registry base URLs and/or
    #   {Registry} instances, checked in the order given
    # @param destination [String] folder downloaded tarballs are written into
    # @param ignore_list [IgnoreList, nil] packages/versions to skip in {#fetch}
    # @raise [ArgumentError] if registries is nil or empty
    def initialize(registries:, destination:, ignore_list: nil)
      raise ArgumentError, 'at least one registry is required' if registries.nil? || registries.empty?

      @registries = registries.map { |entry| entry.is_a?(Registry) ? entry : Registry.new(entry) }
      @destination = destination.to_s
      @ignore_list = ignore_list
    end

    # @param name [String] the package name
    # @param version [String, nil] a specific version, or nil/"latest" for the newest
    # @return [Boolean] true if any configured registry has this package/version
    def available?(name, version = nil)
      !find_registry(name, version).nil?
    end

    # @param name [String] the package name
    # @param version [String, nil] a specific version, or nil/"latest" for the newest
    # @return [Array(Registry, String), nil] the first registry that has this package/version,
    #   paired with the resolved version string; nil if none of them do
    def find_registry(name, version = nil)
      registries.each do |registry|
        resolved = registry.version?(name, version)
        return [registry, resolved] if resolved
      end
      nil
    end

    # Fetches a single package. Skips it if it's on the ignore list, otherwise downloads
    # its tarball into {#destination}.
    #
    # @param package [String, Package] a "name@version" string, a bare name (latest), or a Package
    # @return [FetchResult]
    def fetch(package)
      fetch_package(Package.parse(package))
    end

    # @param packages [Array<String, Package>] see {#fetch}
    # @return [Array<FetchResult>] one result per package, in the same order
    def fetch_all(packages)
      packages.map { |package| fetch(package) }
    end

    # Lists every version of a package published across all configured registries, skipping
    # registries that don't have it at all and filtering out any ignored versions.
    #
    # @param name [String] the package name
    # @return [Hash{String => Array<String>}] versions, keyed by registry base_url, for
    #   registries that have at least one non-ignored version; empty if the whole package is
    #   ignored or no registry has it
    # @raise [HttpError] if a registry that does have the package fails for another reason
    #   (mirrors {#find_registry}/{Registry#version?}, which likewise only treat "not found" as
    #   an expected, non-raising outcome)
    def list_versions(name)
      result = {} # : Hash[String, Array[String]]
      return result if ignored?(Package.new(name, nil))

      registries.each_with_object(result) do |registry, found|
        versions = available_versions(registry, name)
        found[registry.base_url] = versions unless versions.empty?
      end
    end

    # Downloads every non-ignored version of a package that isn't already present in
    # {#destination} (as `name-version.tgz`, the same convention {#fetch} downloads use).
    # A whole-package ignore skips it entirely, without querying any registry; an individual
    # ignored version instead surfaces as a normal `:ignored` {FetchResult}, same as {#fetch}.
    #
    # @param name [String] the package name
    # @return [Array<FetchResult>] one result per version considered, across all registries
    def sync(name)
      whole_package = Package.new(name, nil)
      return [FetchResult.new(package: whole_package, status: :ignored)] if ignored?(whole_package)

      candidate_versions(name).map { |version| sync_version(Package.new(name, version)) }
    end

    private

    def fetch_package(package)
      return FetchResult.new(package: package, status: :ignored) if ignored?(package)

      found = find_registry(package.name, package.version)
      return FetchResult.new(package: package, status: :not_found) unless found

      download_result(package, found)
    rescue HttpError => e
      FetchResult.new(package: package, status: :error, error: e.message)
    end

    def ignored?(package)
      !!ignore_list&.ignored?(package.name, package.version)
    end

    def available_versions(registry, name)
      raw_versions(registry, name).reject { |version| ignored?(Package.new(name, version)) }
    end

    def raw_versions(registry, name)
      registry.versions(name)
    rescue PackageNotFoundError
      []
    end

    def candidate_versions(name)
      registries.flat_map { |registry| raw_versions(registry, name) }.uniq
    end

    def sync_version(package)
      existing_path = download_path(package)
      return FetchResult.new(package: package, status: :skipped, path: existing_path) if File.exist?(existing_path)

      fetch(package)
    end

    def download_path(package)
      File.join(destination, "#{package.name}-#{package.version}.tgz")
    end

    def download_result(package, found)
      registry, resolved_version = found
      name = package.name
      resolved_package = Package.new(name, resolved_version)
      target = download_path(resolved_package)
      registry.download(name, resolved_version, target)
      FetchResult.new(package: resolved_package, status: :downloaded, registry: registry.base_url, path: target)
    end
  end
end
