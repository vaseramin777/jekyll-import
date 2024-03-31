# frozen_string_literal: true

require "jekyll-import"
require "open-uri"
require "open_uri_redirections"
require "hpricot"
require "fileutils"
require "time"
require "safe_yaml"

module JekyllImport
  module Importers
    class WordpressDotCom < Importer
      def self.require_deps
        JekyllImport.require_with_fallback(%w(
          rubygems
          fileutils
          safe_yaml
          hpricot
          time
          open-uri
          open_uri_redirections
        ))
      end

      def self.specify_options(option_parser)
        option_parser.banner = "Usage: jekyll-import [options]"

        option_parser.on("--source=FILE", "WordPress export XML file (default: 'wordpress.xml')") do |source|
          @source = source
        end

        option_parser.on("--no-fetch-images", "Do not fetch the images referenced in the posts (default: false)") do
          @fetch = false
        end

        option_parser.on("--assets_folder=FOLDER", "Folder where assets such as images will be downloaded to (default: 'assets')") do |asset_folder|
          @asset_folder = asset_folder
        end
      end

      # Will modify post DOM tree
      def self.download_images(title, post_hpricot, asset_folder)
        images = post_hpricot.search("img")
        return if images.empty?

        Jekyll.logger.info "Downloading images for #{title}"
        images.each do |i|
          uri = URI.parse(i["src"])

          dst = File.join(asset_folder, File.basename(uri))
          i["src"] = File.join("{{ site.baseurl }}", dst)
          Jekyll.logger.info uri
          if File.exist?(dst)
            Jekyll.logger.info "Already in cache. Clean assets folder if you want a redownload."
            next
          end
          begin
            FileUtils.mkpath(asset_folder)
            open(uri, allow_redirections: :safe) do |f|
              File.open(dst, "wb") do |out|
                out.puts f.read
              end
            end
            Jekyll.logger.info "OK!"
          rescue StandardError => e
            Jekyll.logger.error "Error: #{e.message}"
            Jekyll.logger.error e.backtrace.join("\n")
          end
        end
      end

      class Item
        def initialize(node)
          @node = node
        end

        def text_for(path)
          @node.at(path).inner_text
        end

        def title
          @title ||= text_for(:title).strip
        end

        def permalink_title
          post_name = text_for("wp:post_name")
          # Fallback to "prettified" title if post_name is empty (can happen)
          @permalink_title ||= if post_name.empty?
                                  Wordpress.sluggify(title)
                                else
                                  post_name
                                end
        end

        def published_at
          @published_at ||= begin
            date = text_for("wp:post_date")
            Time.parse(date) if date
          end
        end

        def status
          @status ||= text_for("wp:status")
        end

        def post_password
          @post_password ||= text_for("wp:post_password")
        end

        def post_type
          @post_type ||= text_for("wp:post_type")
        end

        def parent_id
          @parent_id ||= text_for("wp:post_parent")
        end

        def file_name
          @file_name ||= if post_type == "post" && published_at
                           "#{published_at.strftime("%Y-%m-%d")}-#{permalink_title}.html"
                         else
                           "#{permalink_title}.html"
                         end
        end

        def directory_name
          @directory_name ||= if !published_at && post_type == "post"
                                "_drafts"
                              else
                                "_#{post_type}s"
                              end
        end

        def published?
          @published ||= (status == "publish")
        end

        def excerpt
          @excerpt ||= begin
            text = Hpricot(text_for("excerpt:
