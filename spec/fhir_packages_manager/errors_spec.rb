# frozen_string_literal: true

RSpec.describe FhirPackagesManager::Error do
  it 'is a StandardError' do
    expect(described_class.ancestors).to include(StandardError)
  end
end

RSpec.describe FhirPackagesManager::HttpError do
  it 'is a FhirPackagesManager::Error' do
    expect(described_class.ancestors).to include(FhirPackagesManager::Error)
  end

  it 'exposes the message and status' do
    error = described_class.new('boom', 404)

    expect(error.message).to eq('boom')
    expect(error.status).to eq(404)
  end

  it 'allows a nil status' do
    expect(described_class.new('boom', nil).status).to be_nil
  end
end

RSpec.describe FhirPackagesManager::PackageNotFoundError do
  it 'is a FhirPackagesManager::Error' do
    expect(described_class.ancestors).to include(FhirPackagesManager::Error)
  end
end
