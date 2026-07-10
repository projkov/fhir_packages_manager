# frozen_string_literal: true

module FhirPackagesManager
  # Outcome of Manager#fetch for a single package.
  #
  # status is one of :downloaded, :ignored, :not_found, :error
  FetchResult = Struct.new(:package, :status, :registry, :path, :error, keyword_init: true) do
    def downloaded?
      status == :downloaded
    end

    def ignored?
      status == :ignored
    end

    def not_found?
      status == :not_found
    end

    def error?
      status == :error
    end
  end
end
