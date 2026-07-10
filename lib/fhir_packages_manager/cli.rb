# frozen_string_literal: true

require 'optparse'

module FhirPackagesManager
  # Command-line entry point backing the `fhir_packages_manager` executable.
  # See the "CLI" section of the README for usage examples.
  class CLI
    # @return [Array<String>] the supported subcommands
    COMMANDS = %w[fetch check list sync].freeze

    # @return [String] usage text shown on --help and on invalid invocations
    BANNER = <<~USAGE
      Usage: fhir_packages_manager COMMAND package[@version] [package[@version] ...] [options]

      Commands:
        fetch   Download packages into the destination folder
        check   Report which registry (if any) has each package/version
        list    List every version of a package available across registries
        sync    Download every non-ignored version not already in the destination folder

    USAGE

    # Parses argv and runs the requested command (`fetch` or `check`).
    #
    # @param argv [Array<String>] arguments as passed to the executable, e.g. ARGV
    # @return [void]
    def self.run(argv)
      new(argv).run
    end

    # @param argv [Array<String>] see {.run}
    def initialize(argv)
      @argv = argv.dup
      @options = { destination: './fhir_packages', registries: [] } # : Hash[Symbol, untyped]
    end

    # @return [void]
    def run
      parser.parse!(@argv)
      command = @argv.shift
      package_specs = @argv

      return usage_error(1) if !COMMANDS.include?(command) || package_specs.empty?
      return usage_error('Error: at least one --registry URL is required') if @options[:registries].empty?

      dispatch(command, package_specs)
    end

    private

    def dispatch(command, package_specs)
      case command
      when 'fetch'
        fetch(package_specs)
      when 'check'
        check(package_specs)
      when 'list'
        list(package_specs)
      when 'sync'
        sync(package_specs)
      end
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = BANNER
        define_options(opts)
      end
    end

    def define_options(opts)
      opts.on('-r URL', '--registry URL', 'Registry base URL (repeatable, checked in order given)') do |value|
        @options[:registries] << value
      end
      opts.on('-d DIR', '--destination DIR',
              'Destination folder for downloaded packages (default: ./fhir_packages)') do |value|
        @options[:destination] = value
      end
      opts.on('-i PATH', '--ignore-file PATH', 'YAML/JSON file listing packages/versions to ignore') do |value|
        @options[:ignore_file] = value
      end
      opts.on('-h', '--help', 'Show this help') do
        puts opts
        exit
      end
    end

    def usage_error(message_or_status)
      if message_or_status.is_a?(String)
        warn message_or_status
      else
        warn parser
      end
      exit 1
    end

    def manager
      @manager ||= Manager.new(
        registries: @options[:registries],
        destination: @options[:destination],
        ignore_list: load_ignore_list
      )
    end

    def load_ignore_list
      ignore_file = @options[:ignore_file]
      IgnoreList.load(ignore_file) if ignore_file
    end

    def fetch(package_specs)
      results = manager.fetch_all(package_specs)
      results.each { |result| puts fetch_line(result) }
      exit 1 if results.any? { |result| result.not_found? || result.error? }
    end

    def fetch_line(result)
      package = result.package
      path = result.path
      case result.status
      when :downloaded then "OK    #{package} -> #{path} (#{result.registry})"
      when :ignored then "SKIP  #{package} (ignored)"
      when :skipped then "SKIP  #{package} (already exists at #{path})"
      when :not_found then "MISS  #{package} (not found in any registry)"
      when :error then "ERR   #{package}: #{result.error}"
      end
    end

    def check(package_specs)
      package_specs.each do |spec|
        package = Package.parse(spec)
        found = manager.find_registry(package.name, package.version)
        puts check_line(package, found)
      end
    end

    def check_line(package, found)
      return "UNAVAILABLE #{package}" unless found

      registry, version = found
      "AVAILABLE   #{package.name}@#{version} (#{registry.base_url})"
    end

    def list(package_specs)
      package_specs.each do |spec|
        name = Package.parse(spec).name
        list_lines(name, manager.list_versions(name)).each { |line| puts line }
      end
    end

    def list_lines(name, versions_by_registry)
      return ["NONE  #{name} (not found in any registry)"] if versions_by_registry.empty?

      versions_by_registry.map do |base_url, versions|
        "FOUND #{name} @ #{base_url}: #{versions.sort.join(', ')}"
      end
    end

    def sync(package_specs)
      results = package_specs.flat_map { |spec| manager.sync(Package.parse(spec).name) }
      results.each { |result| puts fetch_line(result) }
      exit 1 if results.any? { |result| result.not_found? || result.error? }
    end
  end
end
