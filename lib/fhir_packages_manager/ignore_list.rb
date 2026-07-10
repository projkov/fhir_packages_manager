# frozen_string_literal: true

require 'yaml'
require 'json'

module FhirPackagesManager
  # A list of packages (optionally pinned to a version) to skip when fetching.
  #
  # Loaded from a YAML or JSON file containing a flat array, e.g.:
  #
  #   - hl7.fhir.r4.core           # ignore every version of this package
  #   - name: hl7.fhir.us.core
  #     version: 3.1.0             # ignore only this one version
  class IgnoreList
    def self.load(path)
      data = case File.extname(path).downcase
             when '.json'
               JSON.parse(File.read(path))
             else
               YAML.load_file(path)
             end
      new(data || [])
    end

    def initialize(entries = [])
      @entries = entries.map { |entry| normalize(entry) }
    end

    def ignored?(name, version = nil)
      @entries.any? { |entry| matches?(entry, name, version) }
    end

    private

    def matches?(entry, name, version)
      return false unless entry[:name] == name

      ignored_version = entry[:version]
      ignored_version.nil? || ignored_version == version
    end

    def normalize(entry)
      case entry
      when String
        { name: entry, version: nil }
      when Hash
        normalize_hash(entry)
      else
        raise ArgumentError, "Invalid ignore list entry: #{entry.inspect}"
      end
    end

    def normalize_hash(entry)
      version = entry['version'] || entry[:version]
      { name: entry['name'] || entry[:name], version: version&.to_s }
    end
  end
end
