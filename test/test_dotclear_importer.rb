# frozen_string_literal: true

require "helper"
require "tempfile"
require "fileutils"

Importers::Dotclear.require_deps

class TestDotclearImporter < Test::Unit::TestCase
  def described_class
    Importers::Dotclear
  end

  def setup
    @export_file = File.join(File.dirname(__FILE__), "mocks", "dotclear.txt")
    @tmpdir = Dir.mktmpdir("dotclear_test_#{Time.now.strftime('%Y-%m-%d-%H%M%S')}")
    Dir.chdir(@tmpdir) do
      create_test_files
      @output = capture_output { described_class.run("datafile" => @export_file, "mediafolder" => "media_dir") }
      @post_path = "_drafts/2
