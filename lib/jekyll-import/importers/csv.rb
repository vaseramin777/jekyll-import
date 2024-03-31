# frozen_string_literal: true

module JekyllImport
  module Importers
    class CSV < Importer
      require 'csv'
      require 'fileutils'
      require 'yaml'

      def self.require_deps; end

      def self.specify_options(c)
        c.option "file",            "--file NAME",       "The CSV file to import. (default: 'posts.csv')"
        c.option "no-front-matter", "--no-front-matter", "Do not add the default front matter to the post body. (default: false)"
      end

      # Reads a csv with title, permalink, body, published_at, and filter.
      # It creates a post file for each row in the csv
      def self.process(options)
        file = options.fetch("file", "posts.csv")

        FileUtils.mkdir_p "_posts"
        posts = 0

        begin
          abort "Cannot find the file '#{file}'. Aborting." unless File.file?(file)

          ::CSV.foreach(file, headers: true) do |row|
            next if row["title"].nil? # header

            posts += 1
            write_post(CSVPost.new(row), options)
          rescue CSVPost::MissingDataError => e
            Jekyll.logger.error "Error creating post: #{e.message}"
          rescue StandardError => e

