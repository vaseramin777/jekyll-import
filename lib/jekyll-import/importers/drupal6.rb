# frozen_string_literal: true

require "jekyll-import/importers/drupal_common"

module JekyllImport
  module Importers
    class Drupal6 < Importer
      include DrupalCommon
      extend DrupalCommon::ClassMethods

      # Builds a SQL query to fetch posts from Drupal 6 database
      def self.build_query(prefix, types, engine)
        types = types.join("' OR n.type = '")
        types = "n.type = '#{types}'"

        query = <<~SQL
                SELECT n.nid,
                       n.title,
                       nr.body,
                       nr.teaser,
                       n.created,
                       n.status,
                       ua.dst AS alias,
                       n.type,
                       GROUP_CONCAT( td.name SEPARATOR '|' ) AS tags
                FROM #{prefix}node_revisions AS nr
                JOIN #{prefix}node AS n ON n.nid = nr.nid AND n.vid = nr.vid
                JOIN url_alias AS ua ON ua.src = CONCAT( 'node/', n.nid)
                LEFT JOIN #{prefix}term_node AS tn ON tn.nid = n.nid
                LEFT JOIN #{prefix}term_data AS td ON tn.tid = td.tid
                WHERE (#{types})
                GROUP BY n.nid, ua.dst
                SQL

        begin
          engine.query(query)
        rescue StandardError => e
          puts "Invalid SQL query: #{e.message}"
          raise
        end
      end

      # Builds a SQL query to fetch aliases from Drupal 6 database
      def self.aliases_query(prefix)
        "SELECT src AS source, dst AS alias FROM #{prefix}url_alias WHERE src = ?"
      end

      # Builds post data from SQL query result
      def self.post_data(sql_post_data)
        content = sql_post_data[:body].to_s
        summary = sql_post_data[:teaser].to_s
        tags = (sql_post_data[:tags] || "").downcase.strip

        data = {
          "excerpt"    => summary,
          "categories" => tags.split("|").uniq,
        }

        data["permalink"] = "/" + sql_post_data
