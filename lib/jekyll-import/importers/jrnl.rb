# frozen_string_literal: true

require 'time'
require 'safe_yaml'

module JekyllImport
  module Importers
    class Jrnl < Importer
      def self.require_deps; end

      def self.specify_options(c)
        c.option "file",        "--file FILENAME",      "Journal file. (default: '~/journal.txt')"
        c.option "time_format", "--time_format FORMAT", "Time format of your journal. (default: '%Y-%m-%d %H:%M')"
        c.option "extension",   "--extension EXT",      "Output extension. (default: 'md')"
        c.option "layout",      "--layout NAME",        "Output post layout. (default: 'post')"
      end

      def self.process(options)
        file        = options.fetch("file", "~/journal.txt")
        time_format = options.fetch("time_format", "%Y-%m-%d %H:%M")
        extension   = options.fetch("extension", "md")
        layout      = options.fetch("layout", "post")

        date_length = Time.now.strftime(time_format).length

        file = File.expand_path(file)

        if !File.file?(file)
          abort "The jrnl file was not found. Please make sure '#{file}' exists. You can specify a different file using the --file switch."
        end

        input = File.read(file)
        entries = input.split("\n\n")

        entries.each do |entry|
          next if entry.strip.empty?

          content = entry.split("\n")
          body = get_post_content(content)
          date = get_date(content[0], date_length)
          title = get_title(content[0], date_length)
          slug = create_slug(title)
          filename = create_filename(date, slug, extension)
          meta = create_meta(layout, title, date)

          write_file(filename, meta, body)
        end
      end

      def self.get_post_content(content)
        content[1..-1].join("\n")
      end

      def self.get_date(content, offset)
        Time.strptime(content[0...offset], time_format)
      end

      def self.get_title(content, offset)
        content[offset..-1].strip
      end

      def self.create_slug(title)
        title.downcase.strip.gsub(/\s+/, "-")
      end

      def self.create_filename(date, slug, extension)
        "#{date.strftime("%Y-%m-%d")}-#{slug}.#{extension}"
      end

      def self.create_meta(layout, title, date)
        {
          layout: layout,
          title: title,
          date: date.strftime("%Y-%m-%d %H:%M:%S %z")
        }.to_yaml
      end

      def self.write_file(filename, meta, body)
        File.open("_posts/#{filename}", "w") do |f|
          f.puts meta
          f.puts "---"
          f.puts
          f.puts body
        end
      rescue Errno::ENOENT
        abort "Could not write to file '#{filename}'. Please make sure the '_posts' directory exists and is writable."
      end
    end
  end
end
