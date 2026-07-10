# frozen_string_literal: true

RSpec.describe FhirPackagesManager::Package do
  describe '.parse' do
    it 'splits a name@version spec' do
      package = described_class.parse('hl7.fhir.us.core@6.1.0')

      expect(package.name).to eq('hl7.fhir.us.core')
      expect(package.version).to eq('6.1.0')
    end

    it 'leaves version nil for a bare name' do
      package = described_class.parse('hl7.fhir.us.core')

      expect(package.name).to eq('hl7.fhir.us.core')
      expect(package.version).to be_nil
    end

    it 'returns the same instance when given a Package' do
      original = described_class.new('hl7.fhir.us.core', '6.1.0')

      expect(described_class.parse(original)).to equal(original)
    end

    it 'treats an empty string as an empty name with no version' do
      package = described_class.parse('')

      expect(package.name).to eq('')
      expect(package.version).to be_nil
    end
  end

  describe '#to_s' do
    it 'includes the version when present' do
      expect(described_class.new('hl7.fhir.us.core', '6.1.0').to_s).to eq('hl7.fhir.us.core@6.1.0')
    end

    it 'omits the version when absent' do
      expect(described_class.new('hl7.fhir.us.core', nil).to_s).to eq('hl7.fhir.us.core')
    end
  end
end
