# frozen_string_literal: true

module FhirPackagesManager
  class Error < StandardError; end

  # Raised for any non-2xx/3xx HTTP response from a registry.
  class HttpError < Error
    attr_reader :status

    def initialize(message, status)
      super(message)
      @status = status
    end
  end

  # Raised when a package or version does not exist on a registry.
  class PackageNotFoundError < Error; end
end
