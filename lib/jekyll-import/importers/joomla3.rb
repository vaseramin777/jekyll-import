# frozen_string_literal: true

require 'sequel'
require 'mysql2'
require 'fileutils'
require 'safe_yaml'

module JekyllImport
  module Importers
    class Joomla3 < Importer
      def self.validate(options)
        %w(dbname user prefix).each do |option|
          abort "Missing mandatory option --#{option}." if options[option].nil?
        end

        abort "Missing mandatory option --password." if options["password"].nil?
      end

      def self.specify_options(c)
        c.option "dbname",   "--dbname",   "The name of the Joomla database."
        c.option "user",     "--user",     "The username for the Joomla database."
        c.option "password", "--password", "The password for the Joomla database. (default: '')"
        c.option "host",     "--host",     "The hostname of the Joomla database. (default: 'localhost')"
        c.option "port",     "--port",     "The port number of the Joomla database. (default: 3306)"
        c.option "category", "--category", "The ID of the category to import. (default: 0)"
        c.option "prefix",   "--prefix",   "The table prefix for the Joomla database. (default: 'jos_')"
      end

      def self.require_deps
        # empty
      end

      def self.process(options)
        dbname = options.fetch("dbname")
        user   = options.fetch("user")
        pass   = options.fetch("password", "")
        host   = options.fetch("host", "localhost")
        port   = options.fetch("port", 3306).to_i
        cid    = options.fetch("category", 0)
        table_prefix = options.fetch("prefix", "jos_")

        db = Sequel.connect("mysql2://#{user}:#{pass}@#{host}:#{port}/#{dbname}?encoding=utf8")

        FileUtils.mkdir_p("_posts")

        query = "
          SELECT 
            cn.title, 
            cn.alias, 
            cn.introtext, 
            CONCAT(cn.introtext, cn.fulltext) AS content, 
            cn.created, 
            cn.id, 
            ct.title AS category, 
            u.name AS author 
          FROM 
            #{table_prefix}content AS cn 
            JOIN #{table_prefix}categories AS ct ON cn.catid = ct.id 
            JOIN #{table_prefix}users AS u ON cn.created_by = u.id 
          WHERE 
            (cn.state = '1' OR cn.state = '2')
        "

        query << if cid.positive?
                   " AND cn.catid = ? "
                 else
                   " AND cn.catid != '2' "
                 end

        db.bind_values(query, cid)

        db[query].each do |post|
          title = post[:title]
          slug = post[:alias]
          date = post[:created]
          author = post[:author]
          category = post[:category]
          content = post[:content].chomp
          excerpt = post[:introtext].chomp

          content.gsub!("\n", "<br>")
          excerpt.gsub!("\n", "<br>")

          name = format(
            "%04d-%02d-%02d-%s.markdown",
            date.year, date.month, date.day, slug.gsub(/[^a-z0-9]+/i, "-")
          )

          data = {
            "layout"     => "post",
            "title"      => title.to_s,
            "joomla_id"  => post[:id],
            "joomla_url" => slug,
            "date"       => date,
            "author"     => author,
            "excerpt"    => excerpt.strip.to_s,
            "category"   => category,
          }.delete_if { |_k, v| v.nil? || v == "" }.to_yaml

          File.open("_posts/#{name}", "w") do |f|
            f.puts data
            f.puts "---"
            f.puts content
          end
        end
      end
    end
  end
end

