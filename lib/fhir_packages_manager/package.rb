# frozen_string_literal: true

module FhirPackagesManager
  # A requested package, e.g. "hl7.fhir.us.core@6.1.0" or "hl7.fhir.us.core"
  # (version nil/"latest" means "resolve to the registry's latest version").
  #
  # @!attribute name
  #   @return [String] the FHIR package name, e.g. "hl7.fhir.us.core"
  # @!attribute version
  #   @return [String, nil] the requested version, or nil/"latest" for the newest available
  class Package < Struct.new(:name, :version)
    # Parses a "name@version" (or bare "name") spec string into a Package.
    #
    # @param spec [String, Package] a spec string, or an existing Package (returned as-is)
    # @return [Package]
    def self.parse(spec)
      return spec if spec.is_a?(Package)

      parts = spec.to_s.split('@', 2)
      new(parts[0] || '', parts[1])
    end

    # @return [String] "name@version", or just "name" when version is nil
    def to_s
      version ? "#{name}@#{version}" : name
    end
  end
end
