# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in fhir_packages_manager.gemspec
gemspec

gem 'irb'
gem 'rake', '~> 13.0'

group :development do
  gem 'fasterer', require: false
  gem 'flay', require: false
  gem 'flog', require: false
  gem 'reek', require: false
  gem 'rubocop', require: false
  gem 'steep', require: false
end

group :test do
  gem 'rspec', '~> 3.13', require: false
  gem 'simplecov', require: false
  gem 'webmock', require: false
end
