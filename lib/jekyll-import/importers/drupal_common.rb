# frozen_string_literal: true

require "date"
require "sequel"
require "fileutils"
require "safe_yaml"

module JekyllImport
  module Importers
    module DrupalCommon
      class Importer
        DEFAULTS = {
          "engine"   => "mysql",
          "password" => "",
          "host"     => "127.0.0.1",
          "prefix"   => "",
          "port"     => "3306",
          "types"    => %w(blog story article),
        }.freeze

        def self.specify_options(c)
          c.option "dbname",   "--dbname DB",                 "Database name"
          c.option "user",     "--user USER",                 "Database user name"
          c.option "engine",   "--engine [mysql|postgresql]", "Database engine (default: #{DEFAULTS["engine"].inspect})"
          c.option "password", "--password PW",               "Database user's password (default: #{DEFAULTS["password"].inspect})"
          c.option "host",     "--host HOST",                 "Database host name (default: #{DEFAULTS["host"].inspect})"
          c.option "port",     "--port PORT",                 "Database port name (default: #{DEFAULTS["port"].inspect})"
          c.option "prefix",   "--prefix PREFIX",             "Table prefix name (default: #{DEFAULTS["prefix"].inspect})"

          c.option "types",    "--types TYPE1[,TYPE2[,TYPE3...]]", Array,
                   "The Drupal content types to be imported  (default: #{DEFAULTS["types"].join(",")})"
        end

        def self.require_deps
          JekyllImport.require_with_fallback(%w(
            rubygems
            sequel
            mysql2
            pg
            fileutils
            safe_yaml
          ))
        end

        def initialize(options)
          @dbname = options.fetch("dbname")
          @user = options.fetch("user")
          @engine = options.fetch("engine", DEFAULTS["engine"])
          @pass = options.fetch("password", DEFAULTS["password"])
          @host = options.fetch("host", DEFAULTS["host"])
          @port = options.fetch("port", DEFAULTS["port"])
          @prefix = options.fetch("prefix", DEFAULTS["prefix"])
          @types = options.fetch("types", DEFAULTS["types"])

          @db = if @engine == "postgresql"
                  Sequel.postgres(@dbname, :user => @user, :password => @pass, :host => @host, :encoding => "utf8")
               else
                  Sequel.mysql2(@dbname, :user => @user, :password => @pass, :host => @host, :port => @port, :encoding => "utf8")
               end

          @query = build_query(@prefix, @types, @engine)

          conf = Jekyll.configuration({})
          @src_dir = conf["source"]

          @dirs = {
            :_aliases => @src_dir,
            :_posts   => File.join(@src_dir, "_posts").to_s,
            :_drafts  => File.join(@src_dir, "_drafts").to_s,
            :_layouts => Jekyll.sanitized_path(@src_dir, conf["layouts_dir"].to_s),
          }

          @dirs.each do |_key, dir|
            FileUtils.mkdir_p dir
          end
        end

        def process
          @db[@query].each do |post|
            data, content = post_data(post)

            data["layout"] = post[:type]
            title = data["title"] = post[:title].strip.force_encoding("UTF-8")
            time = data["created"] = post[:created]

            data = data.delete
