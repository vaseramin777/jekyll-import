# frozen_string_literal: true

require 'open-uri'
require 'rss'
require 'fileutils'
require 'safe_yaml'

module JekyllImport
  module Importers
    class S9Y < Importer
      def self.specify_options(c)
        c.option "source", "--source SOURCE", "The URL of the S9Y RSS feed", required: true
      end

      def self.validate(options)
        begin
          uri = URI.parse(options["source"])
          raise ArgumentError, "Invalid URL" unless uri.scheme.in?(%w[http https])
        rescue URI::InvalidURIError
          abort "Invalid URL format. Please provide a valid URL in the format 'http(s)://example.com'."
        end
      end

      def self.require_deps; end

      def self.process(options)
        source = options.fetch("source")

        FileUtils.mkdir_p("_posts")

        begin
          text = URI.open(source).read
        rescue StandardError => e
          abort "Error opening URL: #{e}"
        end

        rss = ::RSS::Parser.parse(text)

        rss.items.each do |item|
          begin
            post_url = extract_post_url(item.link)
            categories = extract_categories(item.categories)
            content = extract_content(item.content_encoded)
            date = extract_date(item.date)
            slug = extract_slug(item.link)
            name = format_post_name(date, slug)

            data = {
              "layout"     => "post",
              "title"      => item.title,
              "categories" => categories,
              "permalink"  => post_url,
              "s9y_link"   => item.link,
              "date"       => item.date,
            }.delete_if { |_k, v| v.nil? || v == "" }.to_yaml

            # Write out the data and content to file
            begin
              File.open("_posts/#{name}", "w") do |f|
                f.puts data
                f.puts "---"
                f.puts content
              end
            rescue StandardError => e
              abort "Error writing file: #{e}"
            end
          rescue StandardError => e
            abort "Error processing item: #{e}"
          end
        end
      end

     
