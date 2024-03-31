# frozen_string_literal: true

module JekyllImport
  module Importers
    class Medium < Importer
      # Specify the options for the Medium importer
      def self.specify_options(c)
        c.option "username",       "--username NAME",  "Medium username"
        c.option "canonical_link", "--canonical_link", "Copy original link as canonical_url to post (default: false)"
        c.option "render_audio",   "--render_audio",   "Render <audio> element in posts for the enclosure URLs (default: false)"
      end

      # Validate the options for the Medium importer
      def self.validate(options)
        fail "Missing mandatory option --username." if options["username"].nil?
        fail "Missing mandatory option --canonical_link." if options["canonical_link"].nil?
      end

      def self.require_deps
        Importers::RSS.require_deps
      end

      # Process the Medium RSS feed and create the Jekyll source directory
      def self.process(options)
        Importers::RSS.process({
          source:         "https://medium.com/feed/@#{options.fetch("username")}",
          render_audio:   options.fetch("render_audio", false),
          canonical_link: options.fetch("canonical_link", false),
          extract_tags:   "category",
        })
      end
    end
  end
end

JekyllImport::Importers::Medium.freeze
JekyllImport::Importers::Medium.specify_options(Jekyll::Commands::Commands.new).freeze
JekyllImport::Importers::Medium.validate(JekyllImport::Importers::Medium::OPTIONS).freeze
