# frozen_string_literal: true

require "sequel"
require "fileutils"
require "safe_yaml"
require "unidecode"

begin
  require "htmlentities"
rescue LoadError
  warn "Could not require 'htmlentities', so the :clean_entities option is now disabled."
  HTMLENTITIES_AVAILABLE = false
else
  HTMLENTITIES_AVAILABLE = true
end

module JekyllImport
  module Importers
    class Roller < Importer
      def self.require_deps
        JekyllImport.require_with_fallback(%w(
          rubygems
          sequel
          fileutils
          safe_yaml
          unidecode
          htmlentities
        ))
      end

      def self.specify_options(cmd)
        cmd.option "dbname",         "--dbname DB",      "Database name."
        cmd.option "user",           "--user USER",      "Database user name."
        cmd.option "password",       "--password PW",    "Database user's password."
        cmd.option "socket",         "--socket SOCKET",  "Database socket. (default: null)"
        cmd.option "host",           "--host HOST",      "Database host name. (default: 'localhost')"
        cmd.option "port",           "--port PORT",      "Database port number. (default: '3306')"
        cmd.option "clean_entities", "--clean_entities", "Whether to clean entities. (default: true)"
        cmd.option "comments",       "--comments",       "Whether to import comments. (default: true)"
        cmd.option "categories",     "--categories",     "Whether to import categories. (default: true)"
        cmd.option "tags",           "--tags",           "Whether to import tags. (default: true)"

        cmd.option "status",         "--status STATUS,STATUS2", Array,
                 "Array of allowed statuses (either ['PUBLISHED'] or ['DRAFT']). (default: ['PUBLISHED'])"
      end

      def self.process(opts)
        options = {
          user: opts.fetch("user", ""),
          pass: opts.fetch("password", ""),
          host: opts.fetch("host", "127.0.0.1"),
          port: opts.fetch("port", "3306"),
          socket: opts.fetch("socket", nil),
          dbname: opts.fetch("dbname", ""),
          clean_entities: opts.fetch("clean_entities", true),
          comments: opts.fetch("comments", true),
          categories: opts.fetch("categories", true),
          tags: opts.fetch("tags", true),
          extension: opts.fetch("extension", "html"),
          status: opts.fetch("status", ["PUBLISHED"]).map(&:to_sym),
        }

        validate_options!(options)

        FileUtils.mkdir_p("_posts")
        FileUtils.mkdir_p("_drafts") if options[:status].include?(:DRAFT)

        db = Sequel.connect(
          adapter:  "mysql2",
          host:     options[:host],
          port:     options[:port],
          socket:   options[:socket],
          database: options[:dbname],
          user:     options[:user],
          password: options[:pass],
          encoding: "utf8"
        )

        posts_query = gen_db_query(
          select: ["weblogentry.id AS id",
                   "weblogentry.status AS status",
                   "weblogentry.title AS title",
                   "weblogentry.anchor AS slug",
                   "weblogentry.updatetime AS date",
                   "weblogentry.text AS content",
                   "weblogentry.summary AS excerpt",
                   "weblogentry.categoryid AS categoryid",
                   "roller_user.fullname AS author",
                   "roller_user.username AS author_login",
                   "roller_user.emailaddress AS author_email",
                   "weblog.handle AS site"],
          table: "weblogentry AS weblogentry",
          join: ["roller_user AS roller_user ON weblogentry.creator = roller_user.username",
                 "weblog AS weblog ON weblogentry.websiteid = weblog.id"],
          condition: condition_for_status(options[:status]),
        )

        db[posts_query].each do |post|
          process_post(post, db, options)
        end
      end

      def self.process_post(post, db, options)
        extension = options[:extension]

        title = post[:title]
        title = clean_entities(title) if options[:clean_entities]

        slug = post[:slug]
        slug = sluggify(title) if !slug || slug.empty?

        date = post[:date] || Time.now
        name = format("%02d-%02d-%02d-%s.%s", date.year, date.month, date.day, slug, extension)

        content = post[:content].to_s
        content = clean_entities(content) if options[:clean_entities]

        excerpt = post[:excerpt].to_s

        permalink = "#{post[:site]}/entry/#{post[:slug]}"

        categories = []
        tags = []

        if options[:categories]
          categories = post_categories(post[:categoryid], db)
        end

        if options[:tags]
          tags = post_tags(post[:id], db)
        end

        comments = []

        if options[:comments]
          comments = post_comments(post[:id], db)
        end

        data = {
          layout: "post",
          status: post[:
