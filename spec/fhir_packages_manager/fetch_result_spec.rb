# frozen_string_literal: true

RSpec.describe FhirPackagesManager::FetchResult do
  let(:package) { FhirPackagesManager::Package.new('hl7.fhir.us.core', '6.1.0') }

  it 'exposes the fields passed to .new' do
    result = described_class.new(package: package, status: :downloaded, registry: 'https://packages.fhir.org',
                                 path: './pkg.tgz', error: nil)

    expect(result.package).to eq(package)
    expect(result.registry).to eq('https://packages.fhir.org')
    expect(result.path).to eq('./pkg.tgz')
    expect(result.error).to be_nil
  end

  describe 'status predicates' do
    it 'downloaded? is true only for :downloaded' do
      expect(described_class.new(package: package, status: :downloaded)).to be_downloaded
      expect(described_class.new(package: package, status: :ignored)).not_to be_downloaded
    end

    it 'ignored? is true only for :ignored' do
      expect(described_class.new(package: package, status: :ignored)).to be_ignored
      expect(described_class.new(package: package, status: :downloaded)).not_to be_ignored
    end

    it 'skipped? is true only for :skipped' do
      expect(described_class.new(package: package, status: :skipped)).to be_skipped
      expect(described_class.new(package: package, status: :downloaded)).not_to be_skipped
    end

    it 'not_found? is true only for :not_found' do
      expect(described_class.new(package: package, status: :not_found)).to be_not_found
      expect(described_class.new(package: package, status: :downloaded)).not_to be_not_found
    end

    it 'error? is true only for :error' do
      expect(described_class.new(package: package, status: :error)).to be_error
      expect(described_class.new(package: package, status: :downloaded)).not_to be_error
    end
  end
end
