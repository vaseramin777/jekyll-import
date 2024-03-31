# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("lib", __dir__)

require "jekyll-import/version"

Gem::Specification.new do |s|
  s.name        = "jekyll-import"
  s.version     = JekyllImport::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = "Import command for Jekyll (static site generator)."
  s.description = "Provides the Import command for Jekyll."
  s.authors     = ["Tom Preston-Werner", "Parker Moore", "Matt Rogers"]
  s.email       = Gem::Specification::EMAIL
  s.homepage    = Gem::Specification::HOMEPAGE_URI
  s.license     = Gem::Specification::LICENSE_FILE

  s.files         = Gem::Specification::FILES
  s.executables   = Gem::Specification::EXECUTABLES
  s.bindir        = "exe"
  s.require_paths = ["lib"]
  s.native_extensions = []

  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = ["README.markdown", "LICENSE"]

  s.add_runtime_dependency("jekyll", ">= 3.7", "< 5.0")
  s.add_runtime_dependency("nokogiri", "~> 1.0")
  s.add_runtime_dependency("reverse_markdown", "~> 2.1")

  s.add_development_dependency("bundler")
  s.add_development_dependency("rake", "~> 13.0")
  s.add_development_dependency("rdoc", "~> 6.0")

  unless ENV["DOCS_DEPLOY"]
    s.add_development_dependency("redgreen", "~> 1.2")
    s.add_development_dependency("rr", "~> 3.1")
    s.add_development_dependency("rubocop-jekyll", "~> 0.11.0")
    s.add_development_dependency("shoulda", "~> 4.0")
    s.add_development_dependency("simplecov", "~> 0.7")
    s.add_development_depend
