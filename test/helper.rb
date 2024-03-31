# .ruby-version
2.7.2

# .gitignore
/log
/tmp

# Gemfile
source 'https://rubygems.org'

gem 'jekyll', '~> 4.2'
gem 'guard'
gem 'guard-rspec'
gem 'rspec'
gem 'simplecov'
gem 'shoulda'
gem 'rr'

# .simplecov
SimpleCov.start do
  add_filter '/spec/'
end

# spec/spec_helper.rb
require 'rubygems'
require 'simplecov'
require 'simplecov-gem-adapter'
require 'shoulda'
require 'rr'
require 'jekyll-import'

SimpleCov.start('gem')

RSpec.configure do |config|
  config.color = true
  config.formatter = :documentation
end

# spec/lib/jekyll_import_spec.rb
require 'spec_helper'

RSpec.describe JekyllImport do
  describe '#dest_dir' do
    it 'returns the path to the destination directory' do
      expect(described_class.dest_dir).to eq(File
