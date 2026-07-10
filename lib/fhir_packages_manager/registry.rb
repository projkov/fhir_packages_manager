# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "fileutils"

module FhirPackagesManager
  # Client for a single FHIR package registry (e.g. https://packages.fhir.org
  # or https://packages.simplifier.net). Both implement the same npm-style
  # registry API: GET /{package} returns metadata with a "versions" map and
  # "dist-tags", and GET /{package}/{version} streams the .tgz tarball.
  class Registry
    MAX_REDIRECTS = 5

    attr_reader :base_url

    def initialize(base_url)
      @base_url = base_url.to_s.chomp("/")
      @metadata_cache = {}
    end

    # Full registry metadata document for a package name.
    def metadata(name)
      @metadata_cache[name] ||= JSON.parse(get("#{base_url}/#{name}"))
    rescue HttpError => e
      raise PackageNotFoundError, "#{name} not found on #{base_url}" if e.status == 404

      raise
    end

    # Returns the resolved version string if the package/version exists on
    # this registry, or nil otherwise ("latest"/nil resolve to dist-tags.latest).
    def version?(name, version = nil)
      meta = metadata(name)
      resolved = resolve_version(meta, version)
      resolved && meta["versions"]&.key?(resolved) ? resolved : nil
    rescue PackageNotFoundError
      nil
    end

    def tarball_url(name, version)
      meta = metadata(name)
      entry = meta.dig("versions", version)
      raise PackageNotFoundError, "#{name}@#{version} not found on #{base_url}" unless entry

      entry.dig("dist", "tarball") || "#{base_url}/#{name}/#{version}"
    end

    # Downloads the package tarball to destination_path and returns it.
    def download(name, version, destination_path)
      FileUtils.mkdir_p(File.dirname(destination_path))
      download_file(tarball_url(name, version), destination_path)
      destination_path
    end

    private

    def resolve_version(meta, version)
      return meta.dig("dist-tags", "latest") if version.nil? || version == "latest"

      version
    end

    def get(url, redirects_left = MAX_REDIRECTS)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
        http.get(uri, "Accept" => "application/json")
      end

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        raise HttpError.new("Too many redirects for #{url}", nil) if redirects_left <= 0

        get(response["location"], redirects_left - 1)
      else
        raise HttpError.new("GET #{url} failed: #{response.code} #{response.message}", response.code.to_i)
      end
    end

    def download_file(url, destination_path, redirects_left = MAX_REDIRECTS)
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 120) do |http|
        http.request_get(uri) do |response|
          case response
          when Net::HTTPSuccess
            File.open(destination_path, "wb") do |file|
              response.read_body { |chunk| file.write(chunk) }
            end
          when Net::HTTPRedirection
            raise HttpError.new("Too many redirects for #{url}", nil) if redirects_left <= 0

            return download_file(response["location"], destination_path, redirects_left - 1)
          else
            raise HttpError.new("GET #{url} failed: #{response.code} #{response.message}", response.code.to_i)
          end
        end
      end
    end
  end
end
