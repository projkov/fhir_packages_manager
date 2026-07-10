# frozen_string_literal: true

require 'tempfile'

RSpec.describe FhirPackagesManager::CLI do
  let(:registry_url) { 'https://cli-registry.test' }

  def run_cli(*args)
    out = StringIO.new
    err = StringIO.new
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = out
    $stderr = err
    status = nil

    begin
      described_class.run(args)
    rescue SystemExit => e
      status = e.status
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end

    { stdout: out.string, stderr: err.string, exit_status: status }
  end

  def stub_metadata(name, versions:)
    body = {
      'name' => name,
      'dist-tags' => { 'latest' => versions.keys.last },
      'versions' => versions.to_h { |version, tarball| [version, { 'dist' => { 'tarball' => tarball } }] }
    }.to_json
    stub_request(:get, "#{registry_url}/#{name}").to_return(status: 200, body: body)
  end

  describe 'invalid invocations' do
    it 'prints usage and exits 1 when called with no arguments' do
      result = run_cli

      expect(result[:exit_status]).to eq(1)
      expect(result[:stderr]).to include('Usage: fhir_packages_manager')
    end

    it 'prints usage and exits 1 for an unknown command' do
      result = run_cli('bogus', 'pkg')

      expect(result[:exit_status]).to eq(1)
      expect(result[:stderr]).to include('Usage: fhir_packages_manager')
    end

    it 'prints usage and exits 1 when a command has no package specs' do
      result = run_cli('fetch', '-r', registry_url)

      expect(result[:exit_status]).to eq(1)
      expect(result[:stderr]).to include('Usage: fhir_packages_manager')
    end

    it 'requires at least one --registry' do
      result = run_cli('fetch', 'hl7.fhir.us.core@6.1.0')

      expect(result[:exit_status]).to eq(1)
      expect(result[:stderr]).to eq("Error: at least one --registry URL is required\n")
    end
  end

  describe '-h/--help' do
    it 'prints the banner and options, then exits successfully' do
      result = run_cli('-h')

      expect(result[:exit_status]).to eq(0)
      expect(result[:stdout]).to include('Usage: fhir_packages_manager')
      expect(result[:stdout]).to include('--registry URL')
    end
  end

  describe 'check command' do
    it 'reports an available package with its resolved version and registry' do
      stub_metadata('hl7.fhir.us.core', versions: { '6.1.0' => "#{registry_url}/hl7.fhir.us.core/6.1.0" })

      result = run_cli('check', 'hl7.fhir.us.core@6.1.0', '-r', registry_url)

      expect(result[:exit_status]).to be_nil
      expect(result[:stdout]).to eq("AVAILABLE   hl7.fhir.us.core@6.1.0 (#{registry_url})\n")
    end

    it 'reports an unavailable package' do
      stub_request(:get, "#{registry_url}/missing.package").to_return(status: 404, body: 'not found')

      result = run_cli('check', 'missing.package', '-r', registry_url)

      expect(result[:exit_status]).to be_nil
      expect(result[:stdout]).to eq("UNAVAILABLE missing.package\n")
    end
  end

  describe 'list command' do
    it 'lists every version found for a package on a registry' do
      stub_metadata('hl7.fhir.us.core', versions: {
                      '3.1.0' => "#{registry_url}/hl7.fhir.us.core/3.1.0",
                      '1.0.0' => "#{registry_url}/hl7.fhir.us.core/1.0.0"
                    })

      result = run_cli('list', 'hl7.fhir.us.core', '-r', registry_url)

      expect(result[:exit_status]).to be_nil
      expect(result[:stdout]).to eq("FOUND hl7.fhir.us.core @ #{registry_url}: 1.0.0, 3.1.0\n")
    end

    it 'reports NONE when no registry has the package' do
      stub_request(:get, "#{registry_url}/missing.package").to_return(status: 404, body: 'not found')

      result = run_cli('list', 'missing.package', '-r', registry_url)

      expect(result[:exit_status]).to be_nil
      expect(result[:stdout]).to eq("NONE  missing.package (not found in any registry)\n")
    end

    it 'excludes an ignored version from the listing' do
      stub_metadata('hl7.fhir.us.core', versions: {
                      '1.0.0' => "#{registry_url}/hl7.fhir.us.core/1.0.0",
                      '2.0.0' => "#{registry_url}/hl7.fhir.us.core/2.0.0"
                    })
      ignore_file = Tempfile.new(['ignore', '.yml'])
      ignore_file.write("- name: hl7.fhir.us.core\n  version: 1.0.0\n")
      ignore_file.close

      result = run_cli('list', 'hl7.fhir.us.core', '-r', registry_url, '-i', ignore_file.path)

      expect(result[:stdout]).to eq("FOUND hl7.fhir.us.core @ #{registry_url}: 2.0.0\n")
    end

    it 'accepts a bare package name and ignores any accidental version suffix' do
      stub_metadata('hl7.fhir.us.core', versions: { '1.0.0' => "#{registry_url}/hl7.fhir.us.core/1.0.0" })

      result = run_cli('list', 'hl7.fhir.us.core@9.9.9', '-r', registry_url)

      expect(result[:stdout]).to eq("FOUND hl7.fhir.us.core @ #{registry_url}: 1.0.0\n")
    end
  end

  describe 'fetch command' do
    it 'downloads an available package and reports OK, without exiting' do
      stub_metadata('hl7.fhir.us.core', versions: { '6.1.0' => "#{registry_url}/hl7.fhir.us.core/6.1.0" })
      stub_request(:get, "#{registry_url}/hl7.fhir.us.core/6.1.0").to_return(status: 200, body: 'tarball bytes')

      Dir.mktmpdir do |dir|
        result = run_cli('fetch', 'hl7.fhir.us.core@6.1.0', '-r', registry_url, '-d', dir)

        expect(result[:exit_status]).to be_nil
        expected_path = File.join(dir, 'hl7.fhir.us.core-6.1.0.tgz')
        expect(result[:stdout]).to eq("OK    hl7.fhir.us.core@6.1.0 -> #{expected_path} (#{registry_url})\n")
        expect(File.read(expected_path)).to eq('tarball bytes')
      end
    end

    it 'reports MISS and exits 1 when a package is not found' do
      stub_request(:get, "#{registry_url}/missing.package").to_return(status: 404, body: 'not found')

      result = run_cli('fetch', 'missing.package', '-r', registry_url)

      expect(result[:exit_status]).to eq(1)
      expect(result[:stdout]).to eq("MISS  missing.package (not found in any registry)\n")
    end

    it 'reports SKIP for an ignored package and does not exit' do
      ignore_file = Tempfile.new(['ignore', '.yml'])
      ignore_file.write("- hl7.fhir.us.core\n")
      ignore_file.close

      result = run_cli('fetch', 'hl7.fhir.us.core@6.1.0', '-r', registry_url, '-i', ignore_file.path)

      expect(result[:exit_status]).to be_nil
      expect(result[:stdout]).to eq("SKIP  hl7.fhir.us.core@6.1.0 (ignored)\n")
    end

    it 'reports ERR and exits 1 when the download fails' do
      stub_metadata('hl7.fhir.us.core', versions: { '6.1.0' => "#{registry_url}/hl7.fhir.us.core/6.1.0" })
      stub_request(:get, "#{registry_url}/hl7.fhir.us.core/6.1.0").to_return(status: 500, body: 'boom')

      Dir.mktmpdir do |dir|
        result = run_cli('fetch', 'hl7.fhir.us.core@6.1.0', '-r', registry_url, '-d', dir)

        expect(result[:exit_status]).to eq(1)
        expect(result[:stdout]).to start_with('ERR   hl7.fhir.us.core@6.1.0:')
      end
    end
  end

  describe 'sync command' do
    it 'downloads a new version, skips one already on disk, and skips an ignored one' do
      stub_metadata('hl7.fhir.us.core', versions: {
                      '1.0.0' => "#{registry_url}/hl7.fhir.us.core/1.0.0",
                      '2.0.0' => "#{registry_url}/hl7.fhir.us.core/2.0.0",
                      '3.0.0' => "#{registry_url}/hl7.fhir.us.core/3.0.0"
                    })
      stub_request(:get, "#{registry_url}/hl7.fhir.us.core/1.0.0").to_return(status: 200, body: 'tarball bytes')

      ignore_file = Tempfile.new(['ignore', '.yml'])
      ignore_file.write("- name: hl7.fhir.us.core\n  version: 2.0.0\n")
      ignore_file.close

      Dir.mktmpdir do |dir|
        existing_path = File.join(dir, 'hl7.fhir.us.core-3.0.0.tgz')
        File.write(existing_path, 'already here')

        result = run_cli('sync', 'hl7.fhir.us.core', '-r', registry_url, '-d', dir, '-i', ignore_file.path)

        expect(result[:exit_status]).to be_nil
        new_path = File.join(dir, 'hl7.fhir.us.core-1.0.0.tgz')
        expect(result[:stdout]).to eq(<<~OUTPUT)
          OK    hl7.fhir.us.core@1.0.0 -> #{new_path} (#{registry_url})
          SKIP  hl7.fhir.us.core@2.0.0 (ignored)
          SKIP  hl7.fhir.us.core@3.0.0 (already exists at #{existing_path})
        OUTPUT
        expect(File.read(new_path)).to eq('tarball bytes')
      end
    end

    it 'reports a single SKIP line and never touches a registry when the whole package is ignored' do
      ignore_file = Tempfile.new(['ignore', '.yml'])
      ignore_file.write("- hl7.fhir.us.core\n")
      ignore_file.close

      result = run_cli('sync', 'hl7.fhir.us.core', '-r', registry_url, '-i', ignore_file.path)

      expect(result[:exit_status]).to be_nil
      expect(result[:stdout]).to eq("SKIP  hl7.fhir.us.core (ignored)\n")
      expect(WebMock).not_to have_requested(:get, /#{Regexp.escape(registry_url)}/)
    end

    it 'reports NONE-equivalent (no output) and does not exit when a registry does not have the package' do
      stub_request(:get, "#{registry_url}/missing.package").to_return(status: 404, body: 'not found')

      result = run_cli('sync', 'missing.package', '-r', registry_url)

      expect(result[:exit_status]).to be_nil
      expect(result[:stdout]).to eq('')
    end

    it 'reports ERR and exits 1 when a download fails' do
      stub_metadata('hl7.fhir.us.core', versions: { '1.0.0' => "#{registry_url}/hl7.fhir.us.core/1.0.0" })
      stub_request(:get, "#{registry_url}/hl7.fhir.us.core/1.0.0").to_return(status: 500, body: 'boom')

      Dir.mktmpdir do |dir|
        result = run_cli('sync', 'hl7.fhir.us.core', '-r', registry_url, '-d', dir)

        expect(result[:exit_status]).to eq(1)
        expect(result[:stdout]).to start_with('ERR   hl7.fhir.us.core@1.0.0:')
      end
    end
  end

  describe 'private dispatch helpers' do
    # `run` only ever calls these with values from COMMANDS / FetchResult#status, so these
    # branches are unreachable from the public API; tested directly for defensive coverage.
    it 'dispatch is a no-op for a command outside COMMANDS' do
      cli = described_class.new([])

      expect(cli.send(:dispatch, 'bogus', ['pkg'])).to be_nil
    end

    it 'fetch_line is nil for a status outside the known set' do
      cli = described_class.new([])
      package = FhirPackagesManager::Package.new('hl7.fhir.us.core', '6.1.0')
      result = FhirPackagesManager::FetchResult.new(package: package, status: :bogus)

      expect(cli.send(:fetch_line, result)).to be_nil
    end
  end
end
