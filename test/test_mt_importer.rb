require "helper"
require "date"
require "factory_bot"

Importers::MT.require_deps

RSpec.configure do |config|
  config.time_zone = "UTC"
end

FactoryBot.define do
  factory :entry do
    entry_id { 1 }
    entry_blog_id { 1 }
    entry_status { Importers::MT::STATUS_PUBLISHED }
    entry_author_id { 1 }
    entry_allow_comments { 0 }
    entry_allow_pings { 0 }
    entry_convert_breaks { "__default__" }
    entry_category_id { nil }
    entry_title { "Lorem Ipsum" }
    entry_excerpt { "Lorem ipsum dolor sit amet, consectetuer adipiscing elit." }
    entry_text { "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Vivamus vitae risus vitae lorem iaculis placerat." }
    entry_text_more { "Aliquam sit amet felis. Etiam congue. Donec risus risus, pretium ac, tincidunt eu, tempor eu, quam. Morbi blandit mollis magna." }
    entry_to_ping_urls { "" }
    entry_pinged_urls { nil }
    entry_keywords { "" }
    entry_tangent_cache { nil }
    entry_created_on { DateTime.now }
    entry_modified_on { DateTime.now }
    entry_created_by { nil }
    entry_modified_by { 1 }
    entry_basename { "lorem_ipsum" }
    entry_atom_id { "tag:www.example.com,#{entry_created_on.year}:/blog/1.4" }
    entry_week_number { "#{entry_created_on.year}#{entry_created_on.cweek}".to_i }
    entry_ping_count { 0 }
    entry_comment_count { 0 }
    entry_authored_on { Time.zone.parse("2013-01-02 00:00:00 -00:00").utc }
    entry_template_id { nil }
    entry_class { "entry" }
  end
end

RSpec.describe TestMTMigrator do
  let(:now) { DateTime.now }
  let(:entry) { FactoryBot.build(:entry) }

  describe "#stub_entry_row" do
    subject { stub_entry_row }

    it "sets layout to post" do
      expect(Importers::MT.post_metadata(subject)["layout"]).to eq("post")
    end

    it "extracts authored_on as date, formatted as 'YYYY-MM-DD HH:MM:SS Z'" do
      expected_date = entry.entry_authored_on.strftime("%Y-%m-%d %H:%M:%S %z")
      expect(Importers::MT.post_metadata(subject)["date"]).to eq(expected_date)
    end

    it "extracts entry_excerpt as excerpt" do
      expect(Importers::MT.post_metadata(subject)["excerpt"]).to eq(entry.entry_excerpt)
    end

    it "extracts entry_id as mt_id" do
      subject = stub_entry_row(entry_id: 123)
      expect(Importers::MT.post_metadata(subject)["mt_id"]).to eq(123)
    end

    it "extracts entry_title as title" do
      expect(Importers::MT.post_metadata(subject)["title"]).to eq(entry.entry_title)
    end

    it "sets published to false if entry_status is not published" do
      subject = stub_entry_row(entry_status: Importers::MT::STATUS_DRAFT)
      expect(Importers::MT.post_metadata(subject)["published"]).to be(false)
    end

    it "does not set published if entry_status is published" do
      expect(Importers::MT.post_metadata(subject)["published"]).to be(nil)
    end
  end

  describe "#post_content" do
    subject { Importers::MT.post_content(entry) }

    it "includes entry_text" do
      expect(subject).to include(entry.entry_text)
    end

    it "includes entry_text_more" do
      expect(subject).to include(entry.entry_text_more)
    end

    it "includes a <!--MORE--> separator when there is entry_text_more" do
      entry = FactoryBot.build(:entry, entry_text_more: "Some more entry")
      expect(subject).to include(Importers::MT::MORE_CONTENT_SEPARATOR)
    end

    it "does not include a <!--MORE--> separator when there is no entry_text_more" do
      entry = FactoryBot.build(:entry, entry_text_more: "")
      expect(subject).not_to include(Importers::MT::MORE_CONTENT_SEPARATOR)
    end
  end

  describe "#post_file_name" do
    subject { Importers::MT.post_file_name(entry) }

    it "includes the entry_authored_on date in the file name" do
