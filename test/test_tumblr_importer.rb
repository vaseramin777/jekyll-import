require "helper"
require "json"

Importers::Tumblr.require_deps

class TestTumblrImporter < Test::Unit::TestCase
  context "A Tumblr blog" do
    setup do
      @jsonPayload = <<~PAYLOAD
        {
          "tumblelog"   : {
            "title"       : "JekyllImport",
            "description" : "Jekyll Importer Test.",
            "name"        : "JekyllImport",
            "timezone"    : "Canada/Atlantic",
            "cname"       : "https://github.com/jekyll/jekyll-import/",
            "feeds"       : []
          },
          "posts-start" : 0,
          "posts-total" : "2",
          "posts-type"  : false,
          "posts"       : [
            {
              "id"             : 54759400073,
              "url"            : "https://github.com/post/54759400073",
              "url-with-slug"  : "http://github.com/post/54759400073/jekyll-test",
              "type"           : "regular",
              "date-gmt"       : "2013-07-06 16:27:23 GMT",
              "date"           : "Sat, 06 Jul 2013 13:27:23",
              "bookmarklet"    : null,
              "mobile"         : null,
              "feed-item"      : "",
              "from-feed-id"   : 0,
              "unix-timestamp" : 1373128043,
              "format"         : "html",
              "reblog-key"     : "0L6yPcHr",
              "slug"           : "jekyll-test",
              "regular-title"  : "Jekyll: Test",
              "regular-body"   : "<p>Testing...</p>",
              "tags"           : ["jekyll"]
            },
            {
              "id"             : "71845593082",
              "url"            : "http://example.com/post/71845593082",
              "url-with-slug"  : "http://example.com/post/7184559
