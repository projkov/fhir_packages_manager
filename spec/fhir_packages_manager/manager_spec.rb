# frozen_string_literal: true

RSpec.describe FhirPackagesManager::Manager do
  let(:registry) { FhirPackagesManager::Registry.new('https://example-registry.test') }
  let(:destination) { '/tmp/fhir_packages_manager_spec' }

  describe '#initialize' do
    it 'raises ArgumentError when registries is nil' do
      expect { described_class.new(registries: nil, destination: destination) }
        .to raise_error(ArgumentError, /at least one registry/)
    end

    it 'raises ArgumentError when registries is empty' do
      expect { described_class.new(registries: [], destination: destination) }
        .to raise_error(ArgumentError, /at least one registry/)
    end

    it 'wraps plain URL strings into Registry instances' do
      manager = described_class.new(registries: ['https://packages.fhir.org'], destination: destination)

      expect(manager.registries.first).to be_a(FhirPackagesManager::Registry)
      expect(manager.registries.first.base_url).to eq('https://packages.fhir.org')
    end

    it 'passes through existing Registry instances unchanged' do
      manager = described_class.new(registries: [registry], destination: destination)

      expect(manager.registries.first).to equal(registry)
    end
  end

  describe '#available?' do
    let(:manager) { described_class.new(registries: [registry], destination: destination) }

    it 'is true when a registry has the package/version' do
      allow(registry).to receive(:version?).with('hl7.fhir.us.core', '6.1.0').and_return('6.1.0')

      expect(manager.available?('hl7.fhir.us.core', '6.1.0')).to be(true)
    end

    it 'is false when no registry has the package/version' do
      allow(registry).to receive(:version?).with('hl7.fhir.us.core', '6.1.0').and_return(nil)

      expect(manager.available?('hl7.fhir.us.core', '6.1.0')).to be(false)
    end
  end

  describe '#find_registry' do
    let(:other_registry) { FhirPackagesManager::Registry.new('https://other-registry.test') }
    let(:manager) { described_class.new(registries: [registry, other_registry], destination: destination) }

    it 'returns the first registry (and resolved version) that has the package' do
      allow(registry).to receive(:version?).and_return('6.1.0')
      allow(other_registry).to receive(:version?)

      expect(manager.find_registry('hl7.fhir.us.core')).to eq([registry, '6.1.0'])
      expect(other_registry).not_to have_received(:version?)
    end

    it 'falls through to the next registry when the first does not have it' do
      allow(registry).to receive(:version?).and_return(nil)
      allow(other_registry).to receive(:version?).and_return('6.1.0')

      expect(manager.find_registry('hl7.fhir.us.core')).to eq([other_registry, '6.1.0'])
    end

    it 'returns nil when no registry has the package' do
      allow(registry).to receive(:version?).and_return(nil)
      allow(other_registry).to receive(:version?).and_return(nil)

      expect(manager.find_registry('hl7.fhir.us.core')).to be_nil
    end
  end

  describe '#fetch' do
    let(:manager) do
      described_class.new(registries: [registry], destination: destination, ignore_list: ignore_list)
    end
    let(:ignore_list) { nil }

    context 'when the package is on the ignore list' do
      let(:ignore_list) { instance_double(FhirPackagesManager::IgnoreList) }

      it 'returns an :ignored result without querying any registry' do
        allow(ignore_list).to receive(:ignored?).with('hl7.fhir.us.core', '6.1.0').and_return(true)
        allow(registry).to receive(:version?)

        result = manager.fetch('hl7.fhir.us.core@6.1.0')

        expect(result.status).to eq(:ignored)
        expect(result.package.to_s).to eq('hl7.fhir.us.core@6.1.0')
        expect(registry).not_to have_received(:version?)
      end
    end

    context 'when no registry has the package' do
      it 'returns a :not_found result' do
        allow(registry).to receive(:version?).and_return(nil)

        result = manager.fetch('hl7.fhir.us.core@6.1.0')

        expect(result.status).to eq(:not_found)
        expect(result.package.to_s).to eq('hl7.fhir.us.core@6.1.0')
      end
    end

    context 'when the package is available' do
      it 'downloads it and returns a :downloaded result' do
        allow(registry).to receive(:version?).and_return('6.1.0')
        allow(registry).to receive(:download)

        result = manager.fetch('hl7.fhir.us.core@latest')

        expected_path = File.join(destination, 'hl7.fhir.us.core-6.1.0.tgz')
        expect(registry).to have_received(:download).with('hl7.fhir.us.core', '6.1.0', expected_path)
        expect(result.status).to eq(:downloaded)
        expect(result.path).to eq(expected_path)
        expect(result.registry).to eq(registry.base_url)
        expect(result.package.version).to eq('6.1.0')
      end
    end

    context 'when the download raises an HttpError' do
      it 'returns an :error result carrying the message' do
        allow(registry).to receive(:version?).and_return('6.1.0')
        allow(registry).to receive(:download).and_raise(FhirPackagesManager::HttpError.new('boom', 500))

        result = manager.fetch('hl7.fhir.us.core@6.1.0')

        expect(result.status).to eq(:error)
        expect(result.error).to eq('boom')
      end
    end
  end

  describe '#fetch_all' do
    let(:manager) { described_class.new(registries: [registry], destination: destination) }

    it 'fetches every package and returns one result per package' do
      allow(registry).to receive(:version?).and_return(nil)

      results = manager.fetch_all(['hl7.fhir.us.core@6.1.0', 'hl7.fhir.r4.core'])

      expect(results.map(&:status)).to eq(%i[not_found not_found])
      expect(results.map { |r| r.package.name }).to eq(['hl7.fhir.us.core', 'hl7.fhir.r4.core'])
    end
  end
end
