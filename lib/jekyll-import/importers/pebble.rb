require 'nokogiri'
require 'safe_yaml'

module Jekyll
  module Importers
    class Pebble < Importer
      def self.require_deps
        begin
          require 'nokogiri'
          require 'safe_yaml'
        rescue LoadError => e
          puts "Error requiring dependencies: #{e.message}"
          exit 1
        end
      end

      def self.specify_options(c)
        super
        c.option "directory", "--directory PATH", "Pebble source directory"
      end

      def self.process(opts)
        options = {
          directory: opts.fetch("directory", "")
        }

        FileUtils.mkdir_p("_posts")
        FileUtils.mkdir_p("_drafts")

        traverse_posts_within(options[:directory]) do |file|
          next if file.end_with?('categories.xml')
          begin
            process_file(file)
          rescue StandardError => e
            Jekyll.logger.error "Error processing file #{file}: #{e.message}"
          end
        end
      end

      def self.traverse_posts_within(directory, &block) 
        Dir.foreach(directory) do |fd|
          path = File.join(directory, fd)
          if fd == '.' || fd == '..'
            next
          elsif File.directory?(path) 
            traverse_posts_within(path, &block)
          elsif path.end_with?('xml')
            yield(path) if block_given?
          else
          end
        end
      end

      def self.process_file(file)
        xml = Nokogiri::XML(File.read(file), nil, encoding: 'UTF-8')
        raise "There doesn't appear to be any XML items at the source (#{file}) provided." unless xml

        doc = xml.xpath("blogEntry")

        title = slugify(doc.xpath('title').text)
        date = Date.parse(doc.xpath('date').text)

        directory = "_posts"
        name = "#{date.strftime('%Y-%m-%d')}-#{title}"

        header = {
          "layout" => 'post',
          "title"  => doc.xpath("title").text,
          "tags"   => doc.xpath("tags").text.split(", "),
          "categories" => doc.xpath('category').text.split(', ')
        }
        header["render_with_liquid"] = false

        path = File.join(directory, "#{name}.html")
        File.open(path, "w") do |f|
          f.puts header.to_yaml
          f.puts "---\n\n"
          f.puts strip_tags(doc.xpath("body").text)
        end

        Jekyll.logger.info "Wrote file #{path} successfully!"
      end

      def self.slugify(string)
        string = string.gsub(/[^\w\s-]/, '').gsub(/[-\s]+/, '-').strip.downcase
      end

      def self.strip_tags(html)
        doc = Nokogiri::HTML(html)
        doc.text
      end
    end
  end
end
