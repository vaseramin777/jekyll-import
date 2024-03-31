#!/usr/bin/env ruby

# For use/testing when no gem is installed
$LOAD_PATH.unshift File.expand_path('../', __FILE__)

require_relative 'jekyll'
require_relative 'mercenary'
require_relative 'colorator'

require 'jekyll-import'

module JekyllImport
  def self.run(args)
    cmd = Mercenary::Command.new(doc: "Import posts from various sources.") do
      add_importer_commands(self)
    end
    cmd.parse!(args)
  end

  # Public: Add the subcommands for each importer
  #
  # cmd - the instance of Mercenary::Command from the
  #
  # Returns a list of valid subcommands
  def self.add_importer_commands(cmd)
    commands = []
    JekyllImport::Importer.subclasses.each do |importer|
      name = importer.to_s.split("::").last.downcase
      commands << name
      cmd.command(name.to_sym) do |c|
        c.syntax "#{name} [options]"
        importer.specify_options(c)
        c.action do |_, options|
          begin
            importer.run(options)
          rescue LoadError => e
            puts "Whoops! Looks like you need to install '#{e.name}' before you can use this importer.".red
            puts ""
            puts "If you're using bundler:"
            puts "  1. Add 'gem \"#{e.name}\"' to your Gemfile"
            puts "  2. Run 'bundle install'"
            puts ""
            puts "If you're not using bundler:"
            puts "  1. Run 'gem install #{e.name}'."
            exit(1)
          end
        end
      end
   
