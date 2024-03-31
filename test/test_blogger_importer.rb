require "helper"
require "tempfile"
require "tmpdir"
require "factory_bot"

Importers::Blogger.require_deps

RSpec.describe TestBloggerImporter do
  let(:listener) { Importers::Blogger::BloggerAtomStreamListener.new }

  before do
    FactoryBot.find_definitions
  end

  describe "#requires_source_option?" do
    it "requires source option" do
      expect {
        Importers::Blogger.validate({})
      }.to raise_error(RuntimeError)

      expect {
        Importers::Blogger.validate("source" => nil)
      }.to raise_error(RuntimeError)

      expect {
        Importers::Blogger.validate("source" => "---not-exists-file-#{$$}.xml")
      }.to raise_error(Errno::ENOENT)

      expect {
        Tempfile.open("blog-foobar.xml") do |file|
          Importers::Blogger.validate("source" => file.path)
        end
      }.not_to raise_error
    end
  end

  describe "#test_broken_file" do
    it "raises an error on parse" do
      Tempfile.open("blog-broken.xml") do |file|
        file << ">>>This is not a XML file.<<<\n"
        file.rewind

        expect {
          Importers::Blogger.process("source" => file.path)
        }.to raise_error(REXML::ParseException)
      end

      Tempfile.open("blog-broken.xml") do |file|
        file << "<aaa><bbb></bbb></aaa>" # broken XML
        file.rewind

        expect {
          Importers::Blogger.process("source" => file.path)
        }.to raise_error(REXML::ParseException)
      end
    end
  end

  describe "#test_postprocessing" do
    it "replace internal link if specified" do
      tmpdir = Dir.mktmpdir
      orig_pwd = Dir.pwd

      Dir.chdir(tmpdir)

      FactoryBot.create(:post0_src, "_posts/1900-01-01-post0.html")
      FactoryBot.create(:post1_src, "_posts/1900-02-01-post1.html")

      Importers::Blogger.postprocess("replace-internal-link" => false)

      expect(File.read("_posts/1900-01-01-post0.html")).to eq(FactoryBot.find(:post0_src))
      expect(File.read("_posts/1900-02-01-post1.html")).to eq(FactoryBot.find(:post1_src))

      Importers::Blogger.postprocess("replace-internal-link" => true, "original-url-base" => "http://foobar.blogspot.com")

      expect(File.read("_posts/1900-01-01-post0.html")).to eq(FactoryBot.find(:post0_replacement))
      expect(File.read("_posts/1900-02-01-post1.html")).to eq(FactoryBot.find(:post1_replacement))

      Dir.chdir(orig_pwd)
      FileUtils.remove_entry_secure(tmpdir)
    end
  end

  describe "#test_the_xml_parser" do
    it "read entries" do
      xml_str = <<EOD
      <!-- snip -->
      EOD

      StringIO.open(xml_str, "r") do |f|
        REXML::Parsers::StreamParser.new(f, listener).parse
      end

      expect(listener.entry_elem_info_array.length).to eq(3)

      expect(listener.entry_elem_info_array[0][:meta][:category]).to eq(["post0.atom.ns.0"])
      expect(listener.entry_elem_info_array[0][:meta][:kind]).to eq("post")
      expect(listener.entry_elem_info_array[0][:meta][:content_type]).to eq("html")
      expect(listener.entry_elem_info_array[0][:meta][:original_url]).to eq("http://foobar.blogspot.com/1900/02/post0.link.html")
      expect(listener.entry_elem_info_array[0][:meta][:published]).to eq("1900-02-01T00:00:00.000Z")
      expect(listener.entry_elem_info_array[0][:meta][:updated]).to eq("1900-02-01T01:00:00.000Z")
      expect(listener.entry_elem_info_array[0][:meta][:title]).to eq("post0.title")
      expect(listener.entry_elem_info_array[0][:body]).to eq("<p>*post0.content*</p>")
      expect(listener.entry_elem_info_array[0][:meta][:author]).to eq("post0.author.name")
      expect(listener.entry_elem_info_array[0][:meta][:thumbnail]).to eq("post0.thumbnail.url")

      expect(listener.entry_elem_info_array[1][:meta][:category]).to eq(["post1.atom.ns.0", "post1.atom.ns.1"])
      expect(listener.entry_elem_info_array[1]
