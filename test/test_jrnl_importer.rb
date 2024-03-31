require "helper"
require "time"

Importers::Jrnl.require_deps

class TestJrnlMigrator < Test::Unit::TestCase
  def before
    @journal = "2013-09-24 11:36 jrnl test case 1.\nThis is a test case for jekyll-import."
    @entries = @journal.split("\n\n")
    @entry = @entries.first.split("\n")
    @date_length = Time.at(0).strftime("%Y-%m-%d %H:%M").length
  end

  def teardown
    File.delete("test_file.md") if File.exist?("test_file.md")
  end

  context "with a valid journal entry" do
    should "have posts" do
      assert @entries.size > 0
    end

    should "have content" do
      assert Importers::Jrnl.get_post_content(@entry)
    end

    should "have date" do
      assert_equal("2013-09-24 11:36", Importers::Jrnl.get_date(@entry[0], @date_length))
    end

    should "have title" do
      assert_equal("jrnl test case 1.", Importers::Jrnl.get_title(@entry[0], @date_length))
    end

    should
