# frozen_string_literal: true

require 'fileutils'

module FhirPackagesManager
  # Orchestrates checking availability across a set of registries, honoring an
  # ignore list, and downloading tarballs into a destination folder.
  class Manager
    attr_reader :registries, :destination, :ignore_list

    def initialize(registries:, destination:, ignore_list: nil)
      raise ArgumentError, 'at least one registry is required' if registries.nil? || registries.empty?

      @registries = registries.map { |entry| entry.is_a?(Registry) ? entry : Registry.new(entry) }
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
      fetch_package(Package.parse(package))
    end

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
