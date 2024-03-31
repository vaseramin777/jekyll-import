# frozen_string_literal: false

module JekyllImport
  module Importers
    class Blogger < Importer
      # Specify options for the Blogger importer.
      def self.specify_options(config)
        config.option "source",
                      "--source NAME",
                      "The XML file (blog-MM-DD-YYYY.xml) path to import"
        config.option "no_blogger_info",
                      "--no-blogger-info",
                      "Don't leave blogger-URL info (id and old URL) in the front matter. (default: false)"
        config.option "replace_internal_link",
                      "--replace-internal-link",
                      "Replace internal links using the post_url liquid tag. (default: false)"
        config.option "comments",
                      "--comments",
                      "Import comments to _comments collection. (default: false)"
      end

      # Validate options for the Blogger importer.
      def self.validate(options)
        raise "Missing mandatory option: --source" if options["source"].nil?
        raise Errno::ENOENT, "File not found: #{options["source"]}" unless File.exist?(options["source"])
      end

      # Require dependencies for the Blogger importer.
      def self.require_deps
        JekyllImport.require_with_fallback(%w(
          rexml/document
          rexml/streamlistener
          rexml/parsers/streamparser
          uri
          time
          fileutils
          safe_yaml
          open-uri
        ))
      end

      # Process the import for the Blogger importer.
      def self.process(options)
        source = options.fetch("source")

        listener = BloggerAtomStreamListener.new
        listener.leave_blogger_info = !options.fetch("no_blogger_info", false)
        listener.comments = options.fetch("comments", false)

        File.open(source, "r") do |file|
          file.flock(File::LOCK_SH)
          REXML::Parsers::StreamParser.new(file, listener).parse
        end

        options["original_url_base"] = listener.original_url_base
        postprocess(options)
      end

      # Post-process after import for the Blogger importer.
      def self.postprocess(options)
        return unless options.fetch("replace_internal_link", false)

        original_url_base = options.fetch("original_url_base", nil)
        return unless original_url_base

        orig_url_pattern = Regexp.new(
          " href=([\"'])?(?:#{Regexp.escape(original_url_base)})?/([0-9]{4})/([0-9]{2})/([^\"']+)\\1"
        )

        Dir.glob("_posts/*.*") do |filename|
          body = nil
          File.open(filename, "r") do |file|
            file.flock(File::LOCK_SH)
            body = file.read
          end

          body.gsub!(orig_url_pattern) do
            quote = Regexp.last_match(1)
            post_file = Dir.glob(
              "_posts/#{Regexp.last_match(2)}-#{Regexp.last_match(3)}-*-#{Regexp.last_match(4).to_s.tr("/", "-")}"
            ).first
            raise "Could not found: _posts/#{Regexp.last_match(2)}-#{Regexp.last_match(3)}-*-#{Regexp.last_match(4).to_s.tr("/", "-")}" if post_file.nil?

            " href=#{quote}{{ site.baseurl }}{% post_url #{File.basename(post_file, ".html")} %}#{quote}"
          end

          File.open(filename, "w") do |file|
            file.flock(File::LOCK_EX)
            file << body
          end
        end
      end

      class BloggerAtomStreamListener
        # Initialize a new BloggerAtomStreamListener instance.
        def initialize
          extend REXML::StreamListener
          extend BloggerAtomStreamListenerMethods

          @leave_blogger_info = true
          @comments = false
        end
      end

      module BloggerAtomStreamListenerMethods
        attr_accessor :leave_blogger_info, :comments
        attr_reader :original_url_base

        # Handle the start of a tag in the Blogger Atom feed.
        def tag_start(name, attributes)
          @tag_bread ||= []
          @tag_bread.push(name)

          case name
          when "entry"
            raise "nest entry element" if @in_entry_elem

            @in_entry_elem = { meta: {}, body: nil }
          when "title"
            raise 'only <title type="
