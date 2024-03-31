# frozen_string_literal: true

require "jekyll-import/importers/drupal_common"

module JekyllImport
  module Importers
    class Drupal7 < Importer
      include DrupalCommon
      extend DrupalCommon::ClassMethods

      # Build a SQL query to fetch posts from a Drupal database
      #
      # prefix - The database table prefix
      # types - An array of node types to fetch
      # engine - The database engine being used
      #
      # Returns a SQL query string
      def self.build_query(prefix, types, engine = nil)
        return nil if types.empty?

        types = types.join("' OR n.type = '")
        types = "n.type = '#{types}'"

        tag_group = case engine
                    when "postgresql"
                      "STR string_agg(td.name, '|')"
                    when "mysql", "mariadb"
                      "GROUP_CONCAT(td.name SEPARATOR '|')"
                    else
                      raise ArgumentError, "Invalid database engine: #{engine}"
                    end

        query = <<~QUERY
                SELECT n.nid,
                       n.title,
                       fdb.body_value,
                       fdb.body_summary,
                       n.created,
                       n.status,
                       n.type,
                       #{tag_group} AS tags
                FROM #{prefix}node AS n
                LEFT JOIN #{prefix}field_data_body AS fdb
                  ON fdb.entity_id = n.nid AND fdb.entity_type = 'node'
                WHERE (#{types})
        QUERY

        query
      end

      # Build a SQL query to fetch URL aliases from a Drupal database
      #
      # prefix - The database table prefix
      #
      # Returns a SQL query string
      def self.aliases_query(prefix)
        "SELECT source, alias FROM #{prefix}url_alias WHERE source = ?"
      end

      # Extract the post data from a SQL result row
      #
      # sql_post_data - A hash containing the post data
      #
      # Returns an array containing the post data and the post content
      def self.post_data(sql_post_data)
        content = sql_post_data[:body_value].to_s
        summary = sql_post_data[:body_summary].to_s
        tags = (sql_post_data[:tags] || "").downcase.strip

        data = {
          "excerpt"    => summary,
          "categories" => tags.split("|") unless tags.empty?
        }

