# frozen_string_literal: true

require "sequel"
require "fileutils"
require "yaml"
require "pathname"
require "active_support/inflector"

module JekyllImport
  module Importers
    class MT < Importer
      SUPPORTED_ENGINES = %w(mysql postgres sqlite).freeze

      STATUS_DRAFT = 1
      STATUS_PUBLISHED = 2
      MORE_CONTENT_SEPARATOR = "<!--more-->"

      def self.default_options
        {
          "blog_id"       => nil,
          "categories"    => true,
          "dest_encoding" => "utf-8",
          "src_encoding"  => "utf-8",
          "comments"      => false,
        }
      end

      def self.require_deps
        JekyllImport.require_with_fallback(%w(
          rubygems
          sequel
          sqlite3
          mysql2
          pg
          fileutils
          safe_yaml
        ))
      end

      def self.specify_options
        Rake::DSL do
          option :dbname,        "Database name.", required: true
          option :user,          "Database user name.", required: true
          option :engine,        "Database engine ('mysql' or 'postgres'). (default: 'mysql')"
          option :password,      "Database user's password. (default: '')"
          option :host,          "Database host name. (default: 'localhost')"
          option :port,          "Custom database port connect to. (default: null)"
          option :blog_id,       "Specify a single Movable Type blog ID to import. (default: null (all blogs))"
          option :categories,    "When true, save post's categories in its YAML front matter. (default: true)"
          option :src_encoding,  "Encoding of strings from database. (default: UTF-8)"
          option :dest_encoding, "Encoding of output strings. (default: UTF-8)"
          option :comments,      "When true, output comments in `_comments` directory. (default: false)"
        end
      end

      # By default this migrator will include posts for all your MovableType blogs.
      # Specify a single blog by providing blog_id.

      # Main migrator function. Call this to perform the migration.
      #
      # dbname::  The name of the database
      # user::    The database user name
      # pass::    The database user's password
      # host::    The address of the MySQL database host. Default: 'localhost'
      # options:: A hash of configuration options
      #
      # Supported options are:
      #
      # blog_id::         Specify a single Movable Type blog to export by providing blog_id.
      #                   Default: nil, importer will include posts for all blogs.
      # categories::      If true, save the post's categories in its
      #                   YAML front matter. Default: true
      # src_encoding::    Encoding of strings from the database. Default: UTF-8
      #                   If your output contains mangled characters, set src_encoding to
      #                   something appropriate for your database charset.
      # dest_encoding::   Encoding of output strings. Default: UTF-8
      # comments::        If true, output comments in _comments directory, like the one
      #                   mentioned at https://github.com/mpalmer/jekyll-static-comments/
      def self.process(options)
        options = default_options.merge(options)

        comments = options.fetch("comments")
        posts_name_by_id = {} if comments

        db = database_from_opts(options).tap(&:connect)

        post_categories = db[:mt_placement].join(:mt_category, category_id: :placement_category_id)

        FileUtils.mkdir_p "_posts"

        posts = db[:mt_entry]
        posts = posts.filter(entry_blog_id: options["blog_id"]) if options["blog_id"]
        posts.symbolize_keys!
        posts.each do |post|
          categories = post_categories
            .filter(placement_entry_id: post[:entry_id])
            .map { |ea| ea[:category_basename] }
            .map { |slug| ["categories", slug] }
            .to_h

          file_name = post_file_name(post, options)

          data = post_metadata(post, options)
          data["categories"] = categories if !categories.empty? && options["categories"]
          yaml_front_matter = data.to_yaml

          # save post path for comment processing
          posts_name_by_id[data["post_id"]] = file_name
