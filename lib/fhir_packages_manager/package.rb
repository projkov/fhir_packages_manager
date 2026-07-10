# frozen_string_literal: true

module FhirPackagesManager
  # A requested package, e.g. "hl7.fhir.us.core@6.1.0" or "hl7.fhir.us.core"
  # (version nil/"latest" means "resolve to the registry's latest version").
  class Package < Struct.new(:name, :version)
    def self.parse(spec)
      return spec if spec.is_a?(Package)

      parts = spec.to_s.split('@', 2)
      new(parts[0] || '', parts[1])
    end

    def to_s
      version ? "#{name}@#{version}" : name
    end
  end
end
