# frozen_string_literal: true

require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'
RuboCop::RakeTask.new

require 'reek/rake/task'
Reek::Rake::Task.new do |t|
  t.source_files = '{lib,exe}/**/*.rb'
end

require 'flay_task'
FlayTask.new(:flay, 200, %w[lib exe])

require 'flog_task'
FlogTask.new(:flog, 30, %w[lib exe], :max_method)

desc 'Check for slow Ruby idioms with fasterer'
task :fasterer do
  sh 'bundle exec fasterer lib exe'
end

desc 'Type-check with Steep'
task :steep do
  sh 'bundle exec steep check'
end

task default: %i[spec rubocop reek fasterer flay flog steep]
