#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'jekyll_import/importers/base'
require 'optionparser'
require 'sequel'
require 'fileutils'
require 'safe_yaml'
require 'unidecode'
require 'nokogiri'
require 'htmlentities'
require 'csv'
require 'json'
require 'pathname'
require 'erb'
require 'date'
require 'uri'

module JekyllImport
  module Importers
    class S9YDatabase < Base
      def self.require_deps
        JekyllImport.require_with_fallback(
          %w(
            rubygems
            sequel
            fileutils
            safe_yaml
            unidecode
            nokogiri
            htmlentities
            csv
            json
            pathname
            erb
            date
            uri
          )
        )
      end

      def self.specify_options
        options = {}

        OptionParser.new do |opts|
          opts.banner = "Usage: jekyll-import s9y_database [options]"

          opts.on("-dDBNAME", "--dbname=DBNAME", "Database name. (default: '')") do |dbname|
            options[:dbname] = dbname
          end

          opts.on("--socket=SOCKET", "Database socket. (default: '')") do |socket|
            options[:socket] = socket
          end

          opts.on("-uUSER", "--user=USER", "Database user name. (default: '')") do |user|
            options[:user] = user
          end

          opts.on("-pPASSWORD", "--password=PASSWORD", "Database user's password. (default: '')") do |password|
            options[:password] = password
          end

          opts.on("-hHOST", "--host=HOST", "Database host name. (default: 'localhost')") do |host|
            options[:host] = host
          end

          opts.on("-PPORT", "--port=PORT", "Custom database port connect to. (default: 3306)") do |port|
            options[:port] = port
          end

          opts.on("--table_prefix=PREFIX", "Table prefix name. (default: 'serendipity_')") do |prefix|
            options[:table_prefix] = prefix
          end

          opts.on("--clean_entities", "Whether to clean entities. (default: true)") do
            options[:clean_entities] = true
          end

          opts.on("--no-clean_entities", "Whether to clean entities. (default: true)") do
            options[:clean_entities] = false
          end

          opts.on("--comments", "Whether to import comments. (default: true)") do
            options[:comments] = true
          end

          opts.on("--no-comments", "Whether to import comments. (default: true)") do
            options[:comments] = false
          end

          opts.on("--categories", "Whether to import categories. (default: true)") do
            options[:categories] = true
          end

          opts.on("--no-categories", "Whether to import categories. (default: true)") do
            options[:categories] = false
          end

          opts.on("--tags", "Whether to import tags. (default: true)") do
            options[:tags] = true
          end

          opts.on("--no-tags", "Whether to import tags. (default: true)") do
            options[:tags] = false
          end

          opts.on("--drafts", "Whether to export drafts as well. (default: true)") do
            options[:drafts] = true
          end

          opts.on("--no-drafts", "Whether to export drafts as well. (default: true)") do
            options[:drafts] = false
          end

          opts.on("--markdown", "convert into markdown format. (default: false)") do
            options[:markdown] = true
          end

          opts.on("--no-markdown", "convert into markdown format. (default: false)") do
            options[:markdown] = false
          end

          opts.on("--permalinks", "preserve S9Y permalinks. (default: false)") do
            options[:permalinks] = true
          end

          opts.on("--no-permalinks", "preserve S9Y permalinks. (default: false)") do
            options[:permalinks] = false
          end

          opts.on("--excerpt_separator=SEPARATOR", "Demarkation for excerpts. (default: '<a id=\"extended\"></a>')") do |separator|
            options[:excerpt_separator] = separator
          end

          opts.on("--includeentry", "Replace macros from the includeentry plugin. (default: false)") do
            options[:includeentry] = true
          end

          opts.on("--no-includeentry", "Replace macros from the includeentry plugin.
