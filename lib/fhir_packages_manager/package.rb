# frozen_string_literal: true

module FhirPackagesManager
  # A requested package, e.g. "hl7.fhir.us.core@6.1.0" or "hl7.fhir.us.core"
  # (version nil/"latest" means "resolve to the registry's latest version").
  Package = Struct.new(:name, :version) do
    def self.parse(spec)
      return spec if spec.is_a?(Package)

      name, version = spec.to_s.split("@", 2)
      new(name, version)
    end

    def to_s
      version ? "#{name}@#{version}" : name
    end
  end
end
