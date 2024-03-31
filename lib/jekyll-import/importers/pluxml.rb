# frozen_string_literal: true

require 'nokogiri'
require 'fileutils'
require 'safe_yaml'

module JekyllImport
  module Importers
    class Pluxml < Importer
      def self.require_deps
        JekyllImport.require_with_fallback(%w(
          nokogiri
          fileutils
          safe_yaml
        ))
      end

      def self.specify_options(c)
        c.option "source",       "--source NAME",  "The PluXml data directory to import."
        c.option "layout",       "--layout NAME",  "The layout to apply. (default: 'post')"
        c.option "avoid_liquid", "--avoid_liquid", "Will add `render_with_liquid: false` in front matter. (default: false)"
      end

      def self.validate(options)
        abort "Missing mandatory option --source." if options["source"].nil?
        options["layout"] = "post" if options["layout"].nil?
        options["avoid_liquid"] = false if options["avoid_liquid"].nil?
      end

      def self.process(options)
        source       = options.fetch("source")
        layout       = options.fetch("layout")
        avoid_liquid = options.fetch("avoid_liquid")

        FileUtils.mkdir_p("_posts")
        FileUtils.mkdir_p("_drafts")

        Dir.glob("*.xml", base: source).each do |df|
          df = File.join(source, df)
          filename = File.basename(df, ".*")

          a_filename = filename.split(".")
          post_name  = a_filename.pop
          file_date  = a_filename.pop
          post_date  = file_date[0..3] + "-" + file_date[4..5] + "-" + file_date[6..7]

          directory = if filename.split(".")[1].split(",")[0] == "draft"
                        "_drafts"
                      else
                        "_posts"
                      end

          name = if directory == "_drafts"
                   post_name.to_s
                  else
                    "#{post_date}-#{post_name}"
                  end

          xml = File.open(df, encoding: "UTF-8") { |f| Nokogiri::XML(f) }
          raise "There doesn't appear to be any XML items at the source (#{df}) provided." unless xml

          doc = xml.xpath("document")
          raise "Missing title in XML data." unless doc.xpath("title").text.present?

          header = {
            "layout" => layout,
            "title"  => doc.xpath("title").text,
            "tags"   => doc.xpath("tags").text.split(", "),
            "created_at" => post_date,
            "updated_at" => post_date
          }
          header["render_with_liquid"] = false if avoid_liquid

          path = File.join(directory, "#{name}.html")
          File.open(path, "w") do |f|
            f.puts header.to_yaml
            f.puts "---\n\n"
            f.puts doc.xpath("chapo").text
            f.puts doc.xpath("content").text
          end

          Jekyll.logger.info "Wrote file #{path} successfully!"
        end
        nil
      end
    end
  end
end
