# frozen_string_literal: true

module JekyllImport
  module Importers
    class Ghost < Importer
      def self.specify_options(c)
        c.option "dbfile", "--dbfile", "Database file (default: ghost.db)"
      end

      def self.require_deps
        JekyllImport.require_with_fallback(%w(
          rubygems
          sequel
          sqlite3
          fileutils
          safe_yaml
        ))
      end

      def self.process(options)
        posts = fetch_posts(options.fetch("dbfile", "ghost.db"))
        if posts.empty?
          puts "No posts found in the database."
        else
          create_directories
          write_posts_to_files(posts)
        end
      end

      private

      def self.fetch_posts(dbfile)
        db = Sequel.sqlite(dbfile)
        query = "SELECT `title`, `slug`, `markdown`, `created_at`, `published_at`, `status`, `page` FROM posts"
        db[query]
      rescue Sequel::DatabaseConnectionError
        puts "Error: Invalid database file."
        []
      end

      def self.create_directories
        %w(_posts _drafts).each { |dir| FileUtils.mkdir_p(dir) }
      end

      def self.get_layout(post)
        post[:page] ? "page" : "post"
      end

      def self.write_posts_to_files(posts)
        posts.each do |post|
          filename, frontmatter, content = generate_file_data(post)
          write_file(filename, frontmatter, content)
        end
      end

      def self.generate_file_data(post)
        draft = post[:status] == "draft"
        date = Time.at(post[draft ? :created_at : :published_at].to_i / 1000)

        layout = get_layout(post)

        if post[:page]
          filename = "#{post[:slug]}.markdown"
        else
          directory = draft ? "_drafts" : "_posts"
          filename = File.join(directory, "#{date.strftime("%Y-%m-%d")}-#{post[:slug]}.markdown")
        end

        frontmatter = {
          "layout" => layout,
          "title" => post[:title],
        }

        frontmatter["date"] = date unless post[:page] && draft
        frontmatter["published"] = false if post[:page] && draft
        frontmatter.delete_if { |_k, v| v.nil? || v == "" }

        [filename, frontmatter.to_yaml, post[:markdown]]
      end

      def self.write_file(filename, frontmatter, content)
        File.open(filename, "w") do |f|
          f.puts frontmatter
          f.puts "---"
          f.puts content
        end
      end
    end
  end
end
