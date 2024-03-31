# frozen_string_literal: true

module JekyllImport
  module Importers
    class Easyblog < Importer
      # Validate mandatory options
      def self.validate(options)
        %w(dbname user).each do |option|
          abort "Missing mandatory option --#{option}." if options[option].nil?
        end
      end

      # Specify options and their descriptions
      def self.specify_options(c)
        c.option "dbname",   "--dbname",   "Database name."
        c.option "user",     "--user",     "Database user name."
        c.option "password", "--password", "Database user's password. (default: '')"
        c.option "host",     "--host",     "Database host name. (default: 'localhost')"
        c.option "section",  "--section",  "Section ID. (default: '1')"
        c.option "prefix",   "--prefix",   "Table prefix name. (default: 'jos_')"
      end

      # Require dependencies and handle exceptions
      def self.require_deps
        begin
          JekyllImport.require_with_fallback(%w(
            rubygems
            sequel
            mysql2
            fileutils
            safe_yaml
          ))
        rescue LoadError => e
          abort "Failed to load required dependencies. Error: #{e}"
        end
      end

      # Process options and import data
      def self.process(options)
        dbname  = options.fetch("dbname")
        user    = options.fetch("user")
        pass    = options.fetch("password", "")
        host    = options.fetch("host", "127.0.0.1")
        section = options.fetch("section", "1")
        table_prefix = options.fetch("prefix", "jos_")

        begin
          # Connect to the MySQL database
          db = Sequel.mysql2(dbname, :user => user, :password => pass, :host => host, :encoding => "utf8")

          # Import data
          import_data(db, table_prefix, section)

          # Close the database connection
          db.disconnect
        rescue Sequel::DatabaseConnectionError => e
          abort "Failed to connect to the database. Error: #{e}"
        end
      end

      # Import data from the MySQL database
      def self.import_data(db, table_prefix, section)
        FileUtils.mkdir_p("_posts")

        query = "
        select
	  ep.`title`, `permalink` as alias, concat(`intro`, `content`) as content, ep.`created`, ep.`id`, ec.`title` as category, tags
        from
          #{table_prefix}easyblog_post ep
          left join #{table_prefix}easyblog_category ec on (ep.category_id = ec.id)
          left join (
            select
              ept.post_id,
              group_concat(et.alias order by alias separator ' ') as tags
            from
              #{table_prefix}easyblog_post_tag ept
              join #{table_prefix}easyblog_tag et on (ept.tag_id = et.id)
            group by
              ept.post_id) x on (ep.id = x.post_id);
        "

        db[query].each do |post|
          # Get required fields and construct Jekyll compatible name.
          title = post[:title]
          slug = post[:alias]
          date = post[:created]
          content = post[:content]
          category = post[:category]
          tags = post[:tags]
          name = format("%02d-%02d-%02d-%s.markdown", date.year, date.month, date.day, slug.gsub(/[^a-z0-9]+/i, '-').downcase)

          # Get the relevant fields as a hash, delete empty fields and convert
          # to YAML for the header.
          data = {
            "layout"     => "post",
            "title"      => title.to_s,
            "joomla_id"  => post[:id],
            "joomla_url" => post[:alias],
            "category"   => post[:category],
            "tags"       => post[:tags],
            "date"       => date,
          }.delete_if { |_k, v| v.nil? || v == "" }

          # Encode the content in UTF-8 and write out the data and content to file
          encoded_content = content.encode!('utf-8', 'binary', invalid: :replace, undef: :replace, replace: '?’)
          File.open("_posts/#{name}", "w") do |f|
            f.puts data.to_yaml(strip_whitespace: true)
            f.puts "---"
            f.puts encoded_content
          end
        end
      end
    end
  end
end

