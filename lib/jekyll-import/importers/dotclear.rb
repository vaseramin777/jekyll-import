# frozen_string_literal: true

module JekyllImport
  module Importers
    class Dotclear < Importer
      class << self
        def specify_options(c)
          c.option "datafile",    "--datafile PATH",   "Dotclear export file."
          c.option "mediafolder", "--mediafolder DIR", "Dotclear media export folder (unpacked media.zip)."
        end

        def require_deps
          JekyllImport.require_with_fallback(%w())
        end

        def validate(opts)
          validate_flags(opts)

          file_path = opts["datafile"]
          return unless File.exist?(file_path)

          begin
            @data = read_export(file_path)
            Jekyll.logger.info "Export File:", file_path
          rescue StandardError => e
            Jekyll.logger.abort_with "Import Error:", "Failed to read export file: #{e.message}"
          end

          assets = @data["media"]
          return if !assets || assets.empty?

          Jekyll.logger.info "", "Media files detected in export data."

          media_dir = opts["mediafolder"]
          return unless File.exist?(media_dir) && !File.empty?(media_dir)

          Jekyll.logger.info "", "Media folder is valid."
        end

        def process(opts)
          import_posts
          import_assets(opts["mediafolder"])
          Jekyll.logger.info "", "and, done!"
        end

        private

        def validate_flags(opts)
          [["datafile"], ["mediafolder"]].each do |flag|
            log_undefined_flag_error(flag.first) if opts[flag.first].nil? || opts[flag.first].empty?
          end
        end

        def log_undefined_flag_error(label)
          Jekyll.logger.abort_with "Import Error:", "--#{label} flag cannot be undefined, null or empty!"
        end

        def read_export(file)
          ignored_sections = %w(category comment link setting)

          File.read(file, :encoding => "utf-8").split("\n\n").each_with_object({}) do |section, data|
            next unless %r!^\[(?<key>.*?) (?<header>.*)\]\n(?<rows>.*)!m =~ section
            next if ignored_sections.include?(key)

            headers = header.split(",")

            data[key] = rows.each_line.with_object([]) do |line, bucket|
              bucket << Hash[headers.zip(line.split('","'))]
            end

            data
          end
        end

        def register_post_tags
          @data["meta"].each_with_object({}) do |entry, tags|
            next unless entry["meta_type"] == "tag"

            post_id = entry["post_id"]
            tags[post_id] ||= []
            tags[post_id] << entry["meta_id"]
          end
        end

        def sanitize_line!(line)
          line.strip!
          line.split('","').map! { |item| item.delete_prefix('"').delete_suffix('"') }
        end

        def import_posts
          tags = register_post_tags
          posts = @data["post"]

          FileUtils.mkdir_p("_drafts") unless posts.empty?
          Jekyll.logger.info "Importing posts.."

          posts.each do |post|
            date, title = post.values_at("post_creadt", "post_title")
            path = File.join("_drafts", Date.parse(date).strftime("%Y-%m-%d-") + Jekyll::Utils.slugify(title) + ".html")

            excerpt = import_post_content(post["post_excerpt_xhtml"])
            excerpt = nil if excerpt.empty?

            content = [excerpt, import_post_content(post["post_content_xhtml"])].tap(&:compact!).join("\n\n")

            front_matter_data = {
              "layout"       => "post",
              "title"        => title,
              "date"         => date,
              "lang"         => post["post_lang"],
              "tags"         => tags[post["post_id"]],
              "original_url" => post["post_url"],
              "excerpt"      => excerpt,
            }.tap(&:compact!)

            Jekyll.logger.info "Creating:", path
            File.write(path, "#{YAML.dump(front_matter_data)}---\n\n#{content}\n")
          end
        end

        def import_post_content(content)
          return "" if content.nil?

          content.strip!
          content.gsub!(REPLACE_RE, REPLACE_MAP)
          content
        end

        def import_assets(src_dir)
          assets = @data["media"]
          FileUtils.mkdir_p("assets/dotclear") if assets && !assets.empty?
          Jekyll.logger.info "Importing assets.."

          assets.each do |asset|
            file_path = File.join(src_dir, asset["media_file"])
            next if !File.exist?(file_path)

            dest_path = File.join("assets/dotclear", asset["media_file"])
            FileUtils.mkdir_p(File.dirname(dest_path))

            Jekyll.logger.info "Copying:", file_path
            Jekyll.logger.info "To:", dest_path
            FileUtils.cp_r
