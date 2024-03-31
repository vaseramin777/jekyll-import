# frozen_string_literal: true

module JekyllImport
  module Importers
    class Posterous < Importer
      def self.specify_options(config)
        config.option "email",     "--email EMAIL", "Posterous email address"
        config.option "password",  "--password PW", "Posterous password"
        config.option "api_token", "--token TOKEN", "Posterous API Token"
      end

      def self.require_deps
        JekyllImport.require_with_fallback(%w(
          rubygems
          jekyll
          fileutils
          uri
          json
          net/http
        ))
      end

      def self.fetch(uri_str, limit = 10)
        return nil if limit.zero?

        response = nil
        Net::HTTP.start("posterous.com") do |http|
          req = Net::HTTP::Get.new(uri_str)
          req.basic_auth email, pass
          response = http.request(req)
        end

        case response
        when Net::HTTPSuccess
          response
        when Net::HTTPRedirection
          fetch(response["location"], limit - 1)
        else
          response.error!
        end
      rescue StandardError => e
        raise ArgumentError, "Failed to fetch data from Posterous API: #{e.message}"
      end

      def self.fetch_images(directory, imgs)
        def self.fetch_one(url, limit = 10)
          return nil if limit.zero?

          response = Net::HTTP.get(URI.parse(url))
          case response
          when Net::HTTPSuccess
            response
          when Net::HTTPRedirection
            fetch_one(response["location"], limit - 1)
          else
            response.error!
          end
        rescue StandardError => e
          raise ArgumentError, "Failed to fetch image: #{e.message}"
        end

        FileUtils.mkdir_p directory
        urls = []
        imgs.each do |img|
          fullurl = img["full"]["url"]
          uri = URI.parse(fullurl)
          imgname = uri.path.split("/")[-1]
          imgdata = fetch_one(fullurl)
          File.open(directory + "/" + imgname, "wb") do |file|
            file.write imgdata
          end
          urls.push(directory + "/" + imgname)
        end

        urls
      rescue StandardError => e
        raise ArgumentError, "Failed to fetch and save images: #{e.message}"
      end

      def self.process(options)
        email = options.fetch("email")
        pass = options.fetch("password")
        api_token = options.fetch("api_token")

        defaults = { include_imgs: false, blog: "primary", base_path: "/" }
        opts = defaults.merge(options)
        FileUtils.mkdir_p "_posts"

        begin
          posts = JSON.parse(fetch("/api/v2/users/me/sites/#{opts[:blog]}/posts?api_token=#{api_token}").body)
        rescue JSON::ParserError
          raise ArgumentError, "Failed to parse JSON data from Posterous API"
        end

        page = 1

        while posts.any?
          posts.each do |post|
            title = post["title"]
            slug = title.gsub(%r![^[:alnum:]]+!, "-").downcase
            date = Date.parse(post["display_date"])
            content = post["body_html"]
            published = !post["is_private"]
            basename = format("%02d-%02d-%02d-%s", date.year, date.month, date.day, slug)
            name = basename + ".html"

            if opts[:include_imgs]
              post_imgs = post["media"]["images"]
              if post_imgs.any?
                img_dir = format("imgs/%s", basename)
                img_urls = fetch_images(img_dir, post_imgs)

                img_urls.map! do |url|
                  "<li><img src='#{opts[:base_path]}#{url}'></li>"
                end
                imgcontent = "<ol>\n" + img_urls.join("\n") + "</ol>\n"

                content = content.sub(%r!\<p\>\[\[posterous-content:[^\]]+\]\]\<\/p\>!, imgcontent)
              end
            end

            data = {
              layout: "post",
              title: title.to_s,
              published: published,
            }.delete_if { |_k, v| v.nil? || v == "" }.to_yaml

            File.open("_posts/#{name}", "w") do |f|
              f.puts data
              f.puts "---"
              f.puts content
            end
          end

          page += 1
          begin
            posts = JSON.parse(fetch("/api/v2/users/me/sites/#{opts[:blog]}/posts?api_token=#{api_token}&page=#{page}").body)
          rescue JSON::ParserError
            raise ArgumentError, "Failed to parse JSON data from Posterous API"
          end
        end
      rescue StandardError => e
        raise ArgumentError, "Failed to process Posterous data: #{e.message}"
      end
    end
  end
end
