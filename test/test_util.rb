require "minitest/autorun"
require_relative "util"

class TestUtil < Minitest::Test
  def test_wpautop_converts_newlines_to_paragraphs
    original = "this is a test\n<p>and it works</p>"
    expected = "<p>this is a test</p>\n<p>and it works</p>\n"
    assert_equal(expected, Util.wpautop(original))
  end

  def test_wpautop_escapes_backslash

