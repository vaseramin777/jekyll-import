# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'safe_yaml'
require 'date'

module JekyllImport
  module Importers
    class Marley < Importer
      def self.validate(options)
        if options["marley_data_dir"].nil?
          Jekyll.logger.abort_with "Missing mandatory option --marley_data_dir."
        else
          raise ArgumentError, "marley dir '#{options["marley_data_dir"]}' not found" unless File.directory?(options["marley_data_dir"])
        end
      end

      def self.regexp
        { :id              => %r!^\d{0,4}-{0,1}(.*)$!,
          :title           => %r!^#\s*(.*)\s+$!,
          :title_with_date => %r!^#\s*(.*)\s+\(([0-9\/]+)\)$!,
          :published_on    => %r!.*\s+\(([0-9\/]+)\)$!,
          :perex           => %r!^([^\#\n]+\n)$!,
          :meta            => %r!^\{\{\n(.*)\}\}\n$!mi, } # Multiline Regexp
      end

      def self.require_deps
        JekyllImport.require_with_fallback(%w(
          fileutils
          safe_yaml
        ))
      end

      def self.specify_options(c)
        c.option "marley_data_dir", "--marley_data_dir DIR", "The dir containing your marley data."
      end

      def self.process(options)
        marley_data_dir = options.fetch("marley_data_dir")

        FileUtils.mkdir_p "_posts"

        posts = 0
        Dir[Pathname.new(marley_data_dir) + "**/*.txt"].each do |f|
          next unless f.file?

          file_content  = f.read
          meta_content  = file_content.slice!(regexp[:meta])
          body          = file_content.sub(regexp[:title], "").sub(regexp[:perex], "").strip

          title = file_content.scan(regexp[:title]).first.to_s.strip
          prerex = file_content.scan(regexp[:perex]).first.to_s.strip
          published_on = DateTime.parse(file_content.scan(regexp[:published_on]).first) rescue f.mtime
          meta = meta_content ? SafeYAML.safe_load(meta_content.scan(regexp[:meta]).to_s) : {}
          meta["title"] = title
          meta["layout"] = "post"

          formatted_date = published_on.strftime("%Y-%m-%d")
          post_name = f.relative_path.to_s.split(%r!/!).last.gsub(%r!\A\d+-!, "")

          name = "#{formatted_date}-#{post_name}"
          post_path = "_posts/#{name}.markdown"
          File.write(post_path, meta.to_yaml + "---\n\n" + (prerex + "\n\n") + body)
          posts += 1
        end
        "Created #{posts} posts!"
      end
    end
  end
end

