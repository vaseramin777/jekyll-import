require "helper"
require "minitest/autorun"

Importers::WordpressDotCom.require_deps

class TestWordpressDotComMigrator < Minitest::Test
  def test_clean_slashes_from_slugs
    test_title = "blogs part 1/2"
    assert_equal("blogs-part-1-2", Importers::WordpressDotCom.sluggify(test_title))
  end
end

class TestWordpressDotComItem < Minitest::Test
  def setup
    @node = Hpricot::XML('
      <item>
        <title>Dear Science</title>
      </item>').at("item")

    @item = Importers::WordpressDotCom::Item.new(@node)
  end

  def test_extract_an_item_s_title
    assert_equal("Dear Science", @item.title)
  end

  def test_use_post_name_for_the_permalink_title_if_it_s_there
    @node = Hpricot::XML('
      <item>
        <wp:post_name>cookie-mountain</wp:post_name>
        <title>Dear Science</title>
      </item>').at("item")

    @item = Importers::WordpressDotCom::Item.new(@node)
    assert_permalink_title("cookie-mountain")
  end

  def test_sluggify_title_for_the_permalink_title_if_post_name_is_empty
    @node = Hpricot::XML('
      <item>
        <wp:post_name></wp:post_name>
        <title>Dear Science</title>
      </item>').at("item")

    @item = Importers::WordpressDotCom::Item.new(@node)
    assert_permalink_title("dear-science")
  end

  def test_return_nil_for_the_excerpt_if_it_s_missing
    @node = Hpricot::XML('
      <item>
        <excerpt:encoded><![CDATA[]]></excerpt:encoded>
      </item>').at("item")

    @item = Importers::WordpressDotCom::Item.new(@node)
    assert_nil(@item.excerpt)
  end

  def test_extract_the_excerpt_as_plaintext_if_it_s_present
    @node = Hpricot::XML('
      <item>
        <excerpt:encoded><![CDATA[...this one weird trick.]]></excerpt:encoded>
      </item>').at("item")

    @item = Importers::WordpressDotCom::Item.new(@node)
    assert_equal("...this one weird trick.", @item.excerpt)
  end

  private

  def assert_permalink_title(expected)
    assert_equal(expected, @item.permalink_title)
  end
end

class TestWordpressDotComPublishedItem < TestWordpressDotComItem
  def setup
    @node = Hpricot::XML('
      <item>
        <title>PostTitle</title>
        <link>https://www.example.com/post/123/post-title/</link>
        <wp:post_name>post-name</wp:post_name>
        <wp:post_type>post</wp:post_type>
        <wp:status>publish</wp:status>
        <wp:post_date>2015-01-23 08:53:47</wp:post_date>
      </item>').at("item")

    @item = Importers::WordpressDotCom::Item.new(@node)
  end

  def test_extract_the_date_time_the_item_was_published
    assert_equal(Time.new(2015, 1, 23, 8, 53, 47), @item.published_at)
  end

  def test_put_the_date_in_the_file_name
    assert_file_name("2015-01-23-post-name.html")
  end

  def test_put_the_file_in_./_posts
    assert_directory_name("_posts")
  end

  def test_know_its_status
    assert_equal("publish", @item.status)
  end

  def test_be_published
    assert_published
  end

  def test_extract_the_link_as_a_permalink
    assert_equal("/post/123/post-title/", @item.permalink)
  end

  private

  def assert_file_name(expected)
    assert_equal(expected, @item.file_name)
  end

  def assert_directory_name(expected)
    assert_equal(expected, @item.directory_name)
  end
end

class TestWordpressDotComDraftItem < TestWordpressDotComItem
  def setup
    @node = Hpricot::XML('
      <item>
        <wp:post_name>post-name</wp:post_name>
        <wp:post_type>post</wp:post_type>
        <wp:status>draft</wp:status>
        <wp:
