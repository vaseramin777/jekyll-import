# frozen_string_literal: true

require 'sequel'
require 'mysql2'
require 'fileutils'
require 'safe_yaml'
require 'erb'
require 'active_support/inflector'

module JekyllImport
  module Importers
    class TextPattern < Importer
      QUERY = "SELECT Title, url_title, Posted, Body, Keywords FROM textpattern WHERE Status = ? OR Status = ?"

      def self.require_deps
        JekyllImport.require_with_fallback(%w(
          rubygems
          sequel
          mysql2
          fileutils
          safe_yaml
        ))
      end

      def self.specify_options(c)
        c.option "dbname",   "--dbname DB",   "Database name."
        c.option "user",     "--user USER",   "Database user name."
        c.option "password", "--password PW", "Database user's password. (default: '')"
        c.option "host",     "--host HOST",   "Database host name. (default: 'localhost')"
      end

      def self.connect(dbname, user, password, host)
        Sequel.connect("mysql2://#{user}:#{password}@#{host}/#{dbname}?encoding=utf8")
      end

      def self.import_posts(db, output_dir)
        FileUtils.mkdir_p output_dir

        db.prepare(QUERY, ['4', '5']).each do |post|
          import_post(post, output_dir)
        end
      end

      def self.import_post(post, output_dir)
        title = post[:Title]
        slug = slugify(title)
        date = post[:Posted]
        content = post[:Body]

        name = [date.strftime("%Y-%m-%d"), slug].join("-") + ".textile"

        data = {
          "layout" => "post",
          "title"  => title.to_s,
          "tags"   => post[:Keywords].split(","),
        }.delete_if { |_k, v| v.nil? || v == "" }

        template = ERB.new("---
#{data.to_yaml}
---
#{content}
")

        File.write("#{output_dir}/#{name}", template.result)
      end

      def self.slugify(title)
        title.downcase.gsub(/[^a-z0-9]+/, '-')
      end

      def self.process(options)
        dbname = options.fetch("dbname")
        user   = options.fetch("user")
        pass   = options.fetch("password", "")
        host   = options.fetch("host", "127.0.0.1")

        begin
          db = connect(dbname, user, pass, host)
          import_posts(db, "_posts")
        rescue StandardError => e
          puts "Error: #{e.message}"
          exit(1)
        end
      end
    end
  end
end

