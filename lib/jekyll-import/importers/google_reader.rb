# frozen_string_literal: true

module JekyllImport
  module Importers
    class GoogleReader < Importer
      def self.validate(options)
        abort "Missing mandatory option --source." if options["source"].nil?
      end

      def self.specify_options(c)
        c.option "source", "--source", "Source XML file of Google Reader export"
      end

      def self.require_deps
        JekyllImport.require_with_fallback(%w(
          rubygems
          rss
          fileutils
          safe_yaml
          open-uri
          rexml/document
          date
        ))
      end

      def self.process(options)
        source = options.fetch("source")

        begin
          content = open(source)
        rescue StandardError => e
          warn "[JekyllImport] Error opening source (#{source}): #{e}"
          return
        end

        return if !File.exist?(source) || !File.readable?(source)

        feed = RSS::Parser.parse(content)

        raise "There doesn't appear to be any RSS items at the source (#{source}) provided." unless feed

        count = 0
        feed.items.each do |item|
          title = item.title.content.to_s
          next if title.empty?

          formatted_date = Date.parse(item.published.to_s)
          next if formatted_date.nil?

          post_name = normalize_post_name(title, formatted_date)
          next if post_name.empty?

          write_post(post_name, title, item.content.content.to_s)
          count += 1
        end

        puts "[JekyllImport] Imported #{count} posts." if count > 0
      end

      private

      def self.normalize_post_name(title, formatted_date)
        post_name = title.downcase.gsub(/[^a-z0-9]+/, "-")
        post_name = "#{formatted_date}-#{post_name}"
        post_name.gsub(/-
