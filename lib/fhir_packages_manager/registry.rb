# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'fileutils'

module FhirPackagesManager
  # Client for a single FHIR package registry (e.g. https://packages.fhir.org
  # or https://packages.simplifier.net). Both implement the same npm-style
  # registry API: GET /{package} returns metadata with a "versions" map and
  # "dist-tags", and GET /{package}/{version} streams the .tgz tarball.
  class Registry
    MAX_REDIRECTS = 5

    attr_reader :base_url

    def initialize(base_url)
      @base_url = base_url.to_s.chomp('/')
      @metadata_cache = {} # : Hash[String, Hash[untyped, untyped]]
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
      resolved && meta['versions']&.key?(resolved) ? resolved : nil
    rescue PackageNotFoundError
      nil
    end

    def tarball_url(name, version)
      meta = metadata(name)
      entry = meta.dig('versions', version)
      raise PackageNotFoundError, "#{name}@#{version} not found on #{base_url}" unless entry

      entry.dig('dist', 'tarball') || "#{base_url}/#{name}/#{version}"
    end

    # Downloads the package tarball to destination_path and returns it.
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
