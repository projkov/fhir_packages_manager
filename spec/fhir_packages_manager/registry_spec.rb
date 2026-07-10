# frozen_string_literal: true

require 'tempfile'

RSpec.describe FhirPackagesManager::Registry do
  let(:base_url) { 'https://example-registry.test' }
  let(:registry) { described_class.new(base_url) }

  let(:metadata_body) do
    {
      'name' => 'hl7.fhir.us.core',
      'dist-tags' => { 'latest' => '6.1.0' },
      'versions' => {
        '3.1.0' => { 'dist' => { 'tarball' => "#{base_url}/hl7.fhir.us.core/3.1.0" } },
        '6.1.0' => { 'dist' => {} }
      }
    }.to_json
  end

  describe '#base_url' do
    it 'strips a trailing slash' do
      expect(described_class.new('https://example-registry.test/').base_url).to eq(base_url)
    end
  end

  describe '#metadata' do
    it 'fetches and parses the registry metadata document' do
      stub = stub_request(:get, "#{base_url}/hl7.fhir.us.core")
             .with(headers: { 'Accept' => 'application/json' })
             .to_return(status: 200, body: metadata_body)

      meta = registry.metadata('hl7.fhir.us.core')

      expect(meta['name']).to eq('hl7.fhir.us.core')
      expect(stub).to have_been_requested.once
    end

    it 'caches the metadata document per package name' do
      stub = stub_request(:get, "#{base_url}/hl7.fhir.us.core").to_return(status: 200, body: metadata_body)

      2.times { registry.metadata('hl7.fhir.us.core') }

      expect(stub).to have_been_requested.once
    end

    it 'raises PackageNotFoundError on a 404' do
      stub_request(:get, "#{base_url}/missing.package").to_return(status: 404, body: 'not found')

      expect { registry.metadata('missing.package') }.to raise_error(FhirPackagesManager::PackageNotFoundError)
    end

    it 're-raises other HTTP errors' do
      stub_request(:get, "#{base_url}/broken.package").to_return(status: 500, body: 'boom')

      expect { registry.metadata('broken.package') }.to raise_error(FhirPackagesManager::HttpError) do |error|
        expect(error.status).to eq(500)
      end
    end
  end

  describe '#version?' do
    before do
      stub_request(:get, "#{base_url}/hl7.fhir.us.core").to_return(status: 200, body: metadata_body)
    end

    it 'returns the version when it exists' do
      expect(registry.version?('hl7.fhir.us.core', '3.1.0')).to eq('3.1.0')
    end

    it 'resolves nil to dist-tags.latest' do
      expect(registry.version?('hl7.fhir.us.core')).to eq('6.1.0')
    end

    it "resolves the literal string 'latest' to dist-tags.latest" do
      expect(registry.version?('hl7.fhir.us.core', 'latest')).to eq('6.1.0')
    end

    it 'returns nil when the version does not exist' do
      expect(registry.version?('hl7.fhir.us.core', '99.0.0')).to be_nil
    end

    it 'returns nil (not raise) when the package does not exist' do
      stub_request(:get, "#{base_url}/missing.package").to_return(status: 404, body: 'not found')

      expect(registry.version?('missing.package')).to be_nil
    end

    it 'returns nil when the metadata document has no versions map at all' do
      stub_request(:get, "#{base_url}/no-versions.package")
        .to_return(status: 200, body: { 'name' => 'no-versions.package' }.to_json)

      expect(registry.version?('no-versions.package', '1.0.0')).to be_nil
    end
  end

  describe '#tarball_url' do
    before do
      stub_request(:get, "#{base_url}/hl7.fhir.us.core").to_return(status: 200, body: metadata_body)
    end

    it 'returns the dist.tarball URL when present' do
      expect(registry.tarball_url('hl7.fhir.us.core', '3.1.0')).to eq("#{base_url}/hl7.fhir.us.core/3.1.0")
    end

    it 'falls back to a constructed URL when dist.tarball is missing' do
      expect(registry.tarball_url('hl7.fhir.us.core', '6.1.0')).to eq("#{base_url}/hl7.fhir.us.core/6.1.0")
    end

    it 'raises PackageNotFoundError when the version entry is missing' do
      expect { registry.tarball_url('hl7.fhir.us.core', '0.0.0') }
        .to raise_error(FhirPackagesManager::PackageNotFoundError)
    end
  end

  describe '#download' do
    it 'downloads the tarball to destination_path, creating parent directories' do
      stub_request(:get, "#{base_url}/hl7.fhir.us.core").to_return(status: 200, body: metadata_body)
      stub_request(:get, "#{base_url}/hl7.fhir.us.core/3.1.0").to_return(status: 200, body: 'fake tarball bytes')

      Dir.mktmpdir do |dir|
        destination = File.join(dir, 'nested', 'hl7.fhir.us.core-3.1.0.tgz')

        result = registry.download('hl7.fhir.us.core', '3.1.0', destination)

        expect(result).to eq(destination)
        expect(File.read(destination)).to eq('fake tarball bytes')
      end
    end

    it 'raises HttpError when the download response is not successful' do
      stub_request(:get, "#{base_url}/hl7.fhir.us.core").to_return(status: 200, body: metadata_body)
      stub_request(:get, "#{base_url}/hl7.fhir.us.core/3.1.0").to_return(status: 500, body: 'boom')

      Dir.mktmpdir do |dir|
        destination = File.join(dir, 'hl7.fhir.us.core-3.1.0.tgz')

        expect { registry.download('hl7.fhir.us.core', '3.1.0', destination) }
          .to raise_error(FhirPackagesManager::HttpError)
      end
    end
  end

  describe 'redirect handling' do
    it 'follows a redirect to completion' do
      stub_request(:get, "#{base_url}/redirecting.package")
        .to_return(status: 302, headers: { 'Location' => "#{base_url}/final.package" })
      stub_request(:get, "#{base_url}/final.package").to_return(status: 200, body: metadata_body)

      expect(registry.metadata('redirecting.package')).to eq(JSON.parse(metadata_body))
    end

    it 'raises HttpError after too many redirects' do
      stub_request(:get, "#{base_url}/looping.package")
        .to_return(status: 302, headers: { 'Location' => "#{base_url}/looping.package" })

      expect { registry.metadata('looping.package') }
        .to raise_error(FhirPackagesManager::HttpError, /Too many redirects/)
    end

    it 'raises HttpError when a redirect has no Location header' do
      stub_request(:get, "#{base_url}/nowhere.package").to_return(status: 302)

      expect { registry.metadata('nowhere.package') }
        .to raise_error(FhirPackagesManager::HttpError, /no Location header/)
    end
  end

  describe 'unsupported URLs' do
    it 'raises HttpError for a non-HTTP scheme' do
      registry = described_class.new('ftp://example-registry.test')

      expect { registry.metadata('pkg') }.to raise_error(FhirPackagesManager::HttpError, /Unsupported URL scheme/)
    end

    it 'raises HttpError when the URL has no host' do
      registry = described_class.new('http:no-host-here')

      expect { registry.metadata('pkg') }.to raise_error(FhirPackagesManager::HttpError, /has no host/)
    end
  end
end
