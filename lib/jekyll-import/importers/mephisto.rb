# frozen_string_literal: true

require 'sequel'
require 'csv'
require 'fileutils'

module JekyllImport
  module Importers
    class Mephisto
      # Connects to a MySQL database using Sequel
      def self.connect(db_config)
        Sequel.mysql2(db_config.fetch('database'),
                       user: db_config['user'],
                       password: db_config['password'],
                       host: db_config['host'],
                       encoding: 'utf8')
      end

      # Exports posts from a MySQL database to a CSV file
      def self.export_to_csv(db_config, csv_file)
        db = connect(db_config)

        sql = <<~SQL
          SELECT title, permalink, body, published_at, filter
          FROM contents
          WHERE user_id = 1 AND type = 'Article'
          ORDER BY published_at
        SQL

        CSV.open(csv_file, 'w') do |csv|
          db.fetch(sql) do |row|
            csv << row.values
          end
        end
      end

      # Imports posts from a CSV file into a Jekyll site
      def self.import_from_csv(csv_file)
        FileUtils.mkdir_p '_posts'

        CSV.foreach(csv_file, headers: true) do |row|
          title = row['title']
          slug = row['permalink']
          date = Date.parse(row['published_at'])
          content = row['body']

          name = [date.year, date.month, date.day, slug].join("-") + ".markdown"

          data = {
            "layout" => "post",
            "title"  => title,
            "mt_id"  => row['filter'],
          }.delete_if { |_k, v| v.nil? || v == "" }.to_yaml

          File.open("_posts/#{name}", "w") do |f|
            f.puts data
            f.puts "---"
            f.puts content
          end
        end
      end

      # Imports posts from a MySQL database into a Jekyll site
      def self.import_from_db(db_config)
        db = connect(db_config)

        db[QUERY].each do |post|
          title = post[:title]
          slug = post[:permalink]
          date = post[:published_at]
          content = post[:body]

          name = [date.year, date.month, date.day, slug].join("-") + ".markdown"

          data = {
            "layout" => "post",
            "title"  => title,
            "mt_id"  => post[:entry_id],
          }.delete_if { |_k, v| v.nil? || v == "" }.to_yaml

          File.open("_posts/#{name}", "w") do |f|
            f.puts data
            f.puts "---"
            f.puts content
          end
        end
      end

      # Query to pull blog posts from all entries across all blogs
      QUERY = "SELECT id,
                      permalink,
                      body,
                      published_at,
                      title,
                      entry_id
               FROM contents
               WHERE user_id = 1 AND
                     type = 'Article' AND
                     published_at IS NOT NULL
               ORDER BY published_at"

      def self.validate(options)
        %w(dbname user).each do |option|
          abort "Missing mandatory option --#{option}." if options[option].nil?
        end
      end

      def self.require_deps
        JekyllImport.require_with_fallback(%w(
          sequel
          mysql2
          csv
          fileutils
        ))
      rescue LoadError => e
        abort "Missing dependency: #{e.name}"
      end

      def self.specify_options(c)
        c.option "dbname",   "--dbname DB",   "Database name"
        c.option "user",     "--user USER",   "Database user name"
        c.option "password", "--password PW", "Database user's password (default: '')"
        c.option "host",     "--host HOST",   "Database host name (default: 'localhost')"
      end
    end
  end
end

