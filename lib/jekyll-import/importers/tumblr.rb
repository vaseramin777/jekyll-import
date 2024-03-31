# frozen_string_literal: true

require "rubygems"
require "fileutils"
require "open-uri"
require "nokogiri"
require "json"
require "uri"
require "time"
require "jekyll"
require "reverse_markdown"

module JekyllImport
  module Importers
    class Tumblr < Importer
      class << self
        def require_deps
          JekyllImport.require_with_fallback(%w(
            fileutils
            open-uri
            nokogiri
            json
            uri
            time
            jekyll
            reverse_markdown
          ))
        end

        # @param content [String]
        # @return [Hash]
        def extract_json(contents)
          beginning = contents.index("{")
          ending    = contents.rindex("}") + 1
          JSON.parse(contents[beginning...ending], symbolize_names: true)
        end

        # @param post [Hash]
        # @param format [String]
        # @return [Hash]
        def post_to_hash(post, format)
          case post[:type]
          when "regular"
            title, content = post.values_at("regular-title", "regular-body")
          when "link"
            title   = post["link-text"] || post["link-url"]
            content = "<a href=\"#{post["link-url"]}\">#{title}</a>"
            content << "<br/>#{post["link-description"]}" unless post["link-description"].nil?
          when "photo"
            title = post[:slug].tr("-", " ")
            if post[:photos].size > 1
              content = +""
              post[:photos].each do |post_photo|
                photo = fetch_photo(post_photo)
                content << "#{photo}<br/>"
                content << post_photo[:caption]
              end
            else
              content = fetch_photo(post[:photos].first)
            end
            content << "<br/>#{post[:photo-caption]}"
          when "audio"
            title, content = post.values_at("id3-title", "audio-player")
            content << "<br/>#{post["audio-caption"]}"
          when "quote"
            title   = post["quote-text"]
            content = "<blockquote>#{post["quote-text"]}</blockquote>"
            content << "&#8212;#{post["quote-source"]}" unless post["quote-source"].nil?
          when "conversation"
            title   = post["conversation-title"]
            content = CSV.generate do |csv|
              post["conversation"].each do |line|
                csv << [line["label"], line["phrase"]]
              end
            end
          when "video"
            title, content = post.values_at("video-title", "video-player")
            unless post["video-caption"].nil?
              if content
                content << "<br/>#{post["video-caption"]}"
              else
                content = post["video-caption"]
              end
            end
          when "answer"
            title, content = post.values_at("question", "answer")
          end

          date  = Time.parse(post["date"]).xmlschema
          title = Nokogiri::HTML(title).text
          title = "no title" if title.empty?
          slug  = if post[:slug] && post[:slug].strip != ""
                    post[:slug]
                  elsif title && title.downcase.gsub(%r![\W]!, "").strip != "" && title != "no title"
                    slug = title.downcase.strip.tr(" ", "-").gsub(%r![\W]!, "")
                    slug.length > 200 ? slug.slice(0..200) : slug
                  else
                    post["id"]
                  end
          {
            name: "#{date}-#{slug}.#{format}",
            header: {
              layout: "post",
              title: title,
              date: date,
              tags: (post["tags"] || []),
              tumblr_url: post["url-with-slug"],
            },
            content: content,
            url: post["url"],
            slug: post["url-with-slug"],
          }
        end

        # @param post_photo [Hash]
        # @return [String]
        def fetch_photo(post_photo)
          url = post_photo["photo-url"] || post_photo["photo-url-500"]
          return url unless @grab_images

          path = Pathname.new("tumblr_files") / post_photo["photo-url"].split("/").last
          path += ".#{post_photo["photo-url"].split(".").last}"

          unless path.exist?
            Jekyll.logger.info "Fetching photo #{url}"
            open(url) do |photo|
              File.open(path, "wb") { |file| file.write(photo.read) }
            end
          end
          "/#{path}"
        end

        # @param posts [Array<Hash>]
        # @param urls [Hash]
        # @return [Array<Hash>]
        def rewrite_urls_and_redirects(posts, urls)
          posts.map do |post|
            urls.each do |tumblr_url, jekyll_url|
              post[:content].gsub!(%r!#{tumblr_url}!i, jekyll_url)
            end
            post[:header][:tumblr_url] = post[:slug]

