# frozen_string_literal: true

module FhirPackagesManager
  # Base class for all errors raised by this gem.
  class Error < StandardError; end

  # Raised for any non-2xx/3xx HTTP response from a registry.
  class HttpError < Error
    # @return [Integer, nil] the HTTP status code, or nil for a connection-level failure
    attr_reader :status

    # @param message [String]
    # @param status [Integer, nil]
    def initialize(message, status)
      super(message)
      @status = status
    end
  end

  # Raised when a package or version does not exist on a registry.
  class PackageNotFoundError < Error; end
end
