# frozen_string_literal: true

require 'tempfile'

RSpec.describe FhirPackagesManager::IgnoreList do
  describe '.load' do
    def write_tempfile(extension, content)
      file = Tempfile.new(['ignore', extension])
      file.write(content)
      file.close
      file.path
    end

    it 'loads a YAML file with bare names and pinned versions' do
      path = write_tempfile('.yml', <<~YAML)
        - hl7.fhir.r4.core
        - name: hl7.fhir.us.core
          version: 3.1.0
      YAML

      list = described_class.load(path)

      expect(list.ignored?('hl7.fhir.r4.core', '4.0.1')).to be(true)
      expect(list.ignored?('hl7.fhir.us.core', '3.1.0')).to be(true)
      expect(list.ignored?('hl7.fhir.us.core', '6.1.0')).to be(false)
    end

    it 'loads a JSON file' do
      path = write_tempfile('.json', '[{"name": "hl7.fhir.us.core", "version": "3.1.0"}]')

      list = described_class.load(path)

      expect(list.ignored?('hl7.fhir.us.core', '3.1.0')).to be(true)
    end

    it 'treats an empty YAML file as an empty list' do
      path = write_tempfile('.yml', '')

      expect(described_class.load(path).ignored?('anything')).to be(false)
    end
  end

  describe '#ignored?' do
    it 'ignores every version when the entry has no pinned version' do
      list = described_class.new(['hl7.fhir.r4.core'])

      expect(list.ignored?('hl7.fhir.r4.core')).to be(true)
      expect(list.ignored?('hl7.fhir.r4.core', '4.0.1')).to be(true)
    end

    it 'ignores only the pinned version' do
      list = described_class.new([{ 'name' => 'hl7.fhir.us.core', 'version' => '3.1.0' }])

      expect(list.ignored?('hl7.fhir.us.core', '3.1.0')).to be(true)
      expect(list.ignored?('hl7.fhir.us.core', '6.1.0')).to be(false)
      expect(list.ignored?('hl7.fhir.us.core')).to be(false)
    end

    it 'accepts symbol-keyed hash entries' do
      list = described_class.new([{ name: 'hl7.fhir.us.core', version: '3.1.0' }])

      expect(list.ignored?('hl7.fhir.us.core', '3.1.0')).to be(true)
    end

    it 'treats a hash entry with no version key as ignoring every version' do
      list = described_class.new([{ 'name' => 'hl7.fhir.us.core' }])

      expect(list.ignored?('hl7.fhir.us.core', '3.1.0')).to be(true)
      expect(list.ignored?('hl7.fhir.us.core')).to be(true)
    end

    it 'returns false for a package not on the list' do
      list = described_class.new(['hl7.fhir.r4.core'])

      expect(list.ignored?('hl7.fhir.us.core')).to be(false)
    end

    it 'returns false for an empty list' do
      expect(described_class.new.ignored?('hl7.fhir.us.core')).to be(false)
    end
  end

  describe 'entry normalization' do
    it 'raises for an entry that is neither a String nor a Hash' do
      expect { described_class.new([42]) }.to raise_error(ArgumentError, /Invalid ignore list entry/)
    end
  end
end
