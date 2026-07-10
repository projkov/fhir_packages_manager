# frozen_string_literal: true

require "fileutils"

module FhirPackagesManager
  # Orchestrates checking availability across a set of registries, honoring an
  # ignore list, and downloading tarballs into a destination folder.
  class Manager
    attr_reader :registries, :destination, :ignore_list

    def initialize(registries:, destination:, ignore_list: nil)
      raise ArgumentError, "at least one registry is required" if registries.nil? || registries.empty?

      @registries = registries.map { |r| r.is_a?(Registry) ? r : Registry.new(r) }
      @destination = destination.to_s
      @ignore_list = ignore_list
    end

    def available?(name, version = nil)
      !find_registry(name, version).nil?
    end

    # Returns [registry, resolved_version] for the first registry that has
    # this package/version, or nil if none of them do.
    def find_registry(name, version = nil)
      registries.each do |registry|
        resolved = registry.version?(name, version)
        return [registry, resolved] if resolved
      end
      nil
    end

    # Fetches a single package (a "name@version" string, a Package, or a bare
    # name for "latest"). Skips it if it's on the ignore list, otherwise
    # downloads its tarball into `destination`.
    def fetch(package)
      package = Package.parse(package)

      return FetchResult.new(package: package, status: :ignored) if ignored?(package)

      found = find_registry(package.name, package.version)
      return FetchResult.new(package: package, status: :not_found) unless found

      registry, resolved_version = found
      target = File.join(destination, "#{package.name}-#{resolved_version}.tgz")
      registry.download(package.name, resolved_version, target)
      FetchResult.new(package: Package.new(package.name, resolved_version), status: :downloaded,
                       registry: registry.base_url, path: target)
    rescue HttpError => e
      FetchResult.new(package: package, status: :error, error: e.message)
    end

    def fetch_all(packages)
      packages.map { |package| fetch(package) }
    end

    private

    def ignored?(package)
      !!ignore_list&.ignored?(package.name, package.version)
    end
  end
end
