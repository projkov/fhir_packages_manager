# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'fileutils'

module FhirPackagesManager
  # Client for a single FHIR package registry (e.g. https://packages.fhir.org
  # or https://packages.simplifier.net). Both implement the same npm-style
  # registry API: `GET /<package>` returns metadata with a "versions" map and
  # "dist-tags", and `GET /<package>/<version>` streams the .tgz tarball.
  class Registry
    # @return [Integer] maximum HTTP redirects followed before raising {HttpError}
    MAX_REDIRECTS = 5

    # @return [String] the registry's base URL, with any trailing slash stripped
    attr_reader :base_url

    # @param base_url [String] e.g. "https://packages.fhir.org"
    def initialize(base_url)
      @base_url = base_url.to_s.chomp('/')
      @metadata_cache = {} # : Hash[String, Hash[untyped, untyped]]
    end

    # Fetches (and caches) the full registry metadata document for a package name.
    #
    # @param name [String] the package name
    # @return [Hash] the parsed npm-style registry metadata ("dist-tags", "versions", etc.)
    # @raise [PackageNotFoundError] if the package doesn't exist on this registry
    # @raise [HttpError] for any other non-2xx/3xx response
    def metadata(name)
      @metadata_cache[name] ||= JSON.parse(get("#{base_url}/#{name}"))
    rescue HttpError => e
      raise PackageNotFoundError, "#{name} not found on #{base_url}" if e.status == 404

      raise
    end

    # @param name [String] the package name
    # @param version [String, nil] a specific version, or nil/"latest" for the newest
    # @return [String, nil] the resolved version string if it exists on this registry,
    #   or nil if the package or version doesn't exist (never raises)
    def version?(name, version = nil)
      meta = metadata(name)
      resolved = resolve_version(meta, version)
      resolved && meta['versions']&.key?(resolved) ? resolved : nil
    rescue PackageNotFoundError
      nil
    end

    # @param name [String] the package name
    # @return [Array<String>] every version published for this package on this registry
    # @raise [PackageNotFoundError] if the package doesn't exist on this registry
    # @raise [HttpError] for any other non-2xx/3xx response
    def versions(name)
      metadata(name)['versions']&.keys || []
    end

    # @param name [String] the package name
    # @param version [String] an exact version, as returned by {#version?}
    # @return [String] the tarball's download URL
    # @raise [PackageNotFoundError] if the name/version doesn't exist on this registry
    def tarball_url(name, version)
      meta = metadata(name)
      entry = meta.dig('versions', version)
      raise PackageNotFoundError, "#{name}@#{version} not found on #{base_url}" unless entry

      entry.dig('dist', 'tarball') || "#{base_url}/#{name}/#{version}"
    end

    # Downloads the package tarball to destination_path, creating parent directories as needed.
    #
    # @param name [String] the package name
    # @param version [String] an exact version, as returned by {#version?}
    # @param destination_path [String] where to write the downloaded .tgz file
    # @return [String] destination_path
    # @raise [PackageNotFoundError] if the name/version doesn't exist on this registry
    # @raise [HttpError] if the download itself fails
    def download(name, version, destination_path)
      FileUtils.mkdir_p(File.dirname(destination_path))
      download_file(tarball_url(name, version), destination_path)
      destination_path
    end

    private

    def resolve_version(meta, version)
      return meta.dig('dist-tags', 'latest') if version.nil? || version == 'latest'

      version
    end

    def get(url)
      request(url, read_timeout: 30) { |http, uri| http.get(uri.request_uri, 'Accept' => 'application/json') }.body
    end

    def download_file(url, destination_path)
      request(url, read_timeout: 120) do |http, uri|
        http.request_get(uri.request_uri) do |response|
          save_body(response, destination_path) if response.is_a?(Net::HTTPSuccess)
        end
      end
    end

    def save_body(response, destination_path)
      File.open(destination_path, 'wb') do |file|
        response.read_body { |chunk| file.write(chunk) }
      end
    end

    # Issues a GET, yielding (http, uri) to perform it, and follows any
    # redirect response by re-issuing the same block against the new location.
    def request(url, read_timeout:, redirects_left: MAX_REDIRECTS, &)
      raise HttpError.new("Too many redirects for #{url}", nil) if redirects_left <= 0

      uri = URI(url)
      raise HttpError.new("Unsupported URL scheme: #{url}", nil) unless uri.is_a?(URI::HTTP)

      host = uri.host or raise HttpError.new("URL has no host: #{url}", nil)

      response = Net::HTTP.start(host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10,
                                                 read_timeout: read_timeout) do |http|
        yield http, uri
      end

      follow(response, url, read_timeout:, redirects_left:, &)
    end

    def follow(response, url, read_timeout:, redirects_left:, &)
      case response
      when Net::HTTPSuccess
        response
      when Net::HTTPRedirection
        location = response['location'] or raise HttpError.new("Redirect from #{url} has no Location header", nil)

        request(location, read_timeout:, redirects_left: redirects_left - 1, &)
      else
        status = response.code.to_i
        raise HttpError.new("GET #{url} failed: #{status} #{response.message}", status)
      end
    end
  end
end
