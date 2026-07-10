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

    def download_result(package, found)
      registry, resolved_version = found
      name = package.name
      target = File.join(destination, "#{name}-#{resolved_version}.tgz")
      registry.download(name, resolved_version, target)
      FetchResult.new(package: Package.new(name, resolved_version), status: :downloaded,
                      registry: registry.base_url, path: target)
    end
  end
end
