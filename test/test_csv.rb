# encoding: UTF-8

require_relative "helper"

Importers::CSV.require_deps

class TestCSVImporter < Test::Unit::TestCase
  sample_row = [
    "My Title",
    "/2015/05/05/hi.html",
    "Welcome to Jekyll!\n\nI am a post body.",
    "2015-01-10",
    "markdown",
  ]

  context "CSVPost" do
    should "parse published_at to DateTime" do
      post = Importers::CSV::CSVPost.new(sample_row)
      assert_kind_of DateTime, post.published_at, "post.published_at should be a DateTime"
      assert_equal "2015-01-10", post.published_at.strftime("%Y-%m-%d")
    end

    should "pull in metadata properly" do
      post = Importers::CSV::CSVPost.new(sample_row)
      assert_equal sample_row[0], post.title
      assert_equal sample_row[1], post.permalink
      assert_equal sample_row[2], post.body
      assert_equal sample_row[4], post.markup
    end

    should "correctly construct source filename" do
      post = Importers::CSV::CSVPost.new(sample_row)
      assert_equal "2015-01-10-hi.markdown", post.filename
    end
  end

  context "CSV importer" do
    should "write post to proper place" do
      FileUtils.mkdir_p "tmp/_posts"
      Dir.chdir("tmp") do
        post = Importers::CSV::CSVPost.new(sample_row)
        Importers::CSV.write_post(post, {})
        output_filename = "_posts/2015-01-10-hi.markdown"
        assert File.exist?(output_filename), "Post should be written."

        File.write(output_filename, "")
        File.write(output_filename, "---\nlayout: post\n", mode: "a")
        File.write(output_filename, "title: My Title\n", mode: "a")
        File.write(output_filename, "date: '2015-01-10T00:00:00+00:00'\n", mode: "a")
        File.write(output_filename, "permalink: \"/2015/05/05/hi.html\"\n", mode: "a")
        File.write(output_filename, "---\n", mode: "
