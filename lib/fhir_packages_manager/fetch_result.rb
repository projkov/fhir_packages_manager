# frozen_string_literal: true

module FhirPackagesManager
  # Outcome of {Manager#fetch} for a single package.
  #
  # @!attribute package
  #   @return [Package] the package that was requested (version resolved, when downloaded)
  # @!attribute status
  #   @return [Symbol] one of :downloaded, :ignored, :not_found, :error
  # @!attribute registry
  #   @return [String, nil] the base URL of the registry that served the package, if downloaded
  # @!attribute path
  #   @return [String, nil] where the tarball was written, if downloaded
  # @!attribute error
  #   @return [String, nil] the error message, when status is :error
  class FetchResult < Struct.new(:package, :status, :registry, :path, :error, keyword_init: true)
    # @return [Boolean] true if the package was downloaded successfully
    def downloaded?
      status == :downloaded
    end

    # @return [Boolean] true if the package was skipped because it's on the ignore list
    def ignored?
      status == :ignored
    end

    # @return [Boolean] true if no registry had the package/version
    def not_found?
      status == :not_found
    end

    # @return [Boolean] true if downloading raised an HTTP error
    def error?
      status == :error
    end
  end
end
