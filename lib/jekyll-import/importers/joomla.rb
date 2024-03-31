# frozen_string_literal: true

require "sequel"
require "mysql2"
require "fileutils"
require "safe_yaml"

module JekyllImport
  module Importers
    class Joomla < Importer
      def self.validate(options)
        %w(dbname user).each do |option|
          abort "Missing mandatory option --#{option}." if options[option].nil?
        end

        %w(section prefix).each do |option|
          abort "Missing mandatory option --#{option}." if options[option].nil?
          abort "Invalid option --#{option}: expected an integer." unless options[option].is_a?(Integer)
        end
      end

      def self.specify_options(c)
        c.option "dbname",   "--dbname",   "Database name."
        c.option "user",     "--user",     "Database user name."
        c.option "password", "--password", "Database user's password. (default: '')"
        c.option "host",     "--host",     "Database host name. (default: 'localhost')"
        c.option "port",     "--port",     "Database port. (default: '3306')"
        c.option "section",  "--section",  "Section ID. (default: '1')"
        c.option "prefix",   "--prefix",   "Table prefix name. (default: 'jos_')"
      end

      def self.require_deps
        require "rubygems"
        require "sequel"
        require "mysql2"
        require "fileutils"
        require "safe_yaml"
      end

      def self.process(options)
        dbname  = options.fetch("dbname")
        user    = options.fetch("user")
        pass    = options.fetch("password", "")
        host    = options.fetch("host", "127.0.0.1")
        port    = options.fetch("port", 3306).to_i
        section = options.fetch("section", "1").to_i
        prefix  = options.fetch("prefix", "jos_")

        db = Sequel.connect("mysql2://#{user}:#{pass}@#{host}:#{port}/#{dbname}?encoding=utf8")

        FileUtils.mkdir_p("_posts")

        query = "SELECT `title`, `alias`, CONCAT(`introtext`,`fulltext`) as content, `created`, `id` FROM #{prefix}content WHERE (state = '0' OR state = '1') AND sectionid = #{section}"

        db[query].each do |post|
          title = post[:title]
          date = post[:created]
          content = post[:content]
          id = post[:id]

          slug = if !post[:alias] || post[:alias].empty?
                   title.downcase.parameterize
                 else
                   post[:alias].downcase.parameterize
                 end

          name = format("%02d-%02d-%02d-%03d-%s.markdown", date.year, date.month, date.day, id, slug)

          data = {
            "layout"     => "post",
            "title"      => title.to_s,
            "joomla_id"  => post[:id],
            "joomla_url" => post[:alias],
            "date"       => date,
          }.delete_if { |_k, v| v.nil? || v == "" }.to_yaml

          File.open("_posts/#{name}", "w") do |f|
            f.puts data
            f.puts "---"
            f.puts content
          end
        end

        disconnect_database(db)
      end

      def self.disconnect_database(db)
        db.disconnect
      end

      def self.sluggify(title)
        title.downcase.parameterize
      end
    end
  end
end
