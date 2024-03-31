# frozen_string_literal: true

module JekyllImport
  module Util
    # Ruby translation of wordpress wpautop (see https://core.trac.wordpress.org/browser/trunk/src/wp-includes/formatting.php)
    #
    # A group of regex replaces used to identify text formatted with newlines and
    # replace double line-breaks with HTML paragraph tags. The remaining
    # line-breaks after conversion become <<br />> tags, unless $br is set to false
    #
    # @param string pee The text which has to be formatted.
    # @param bool br Optional. If set, this will convert all remaining line-breaks after paragraphing. Default true.
    # @return string Text which has been converted into correct paragraph tags.
    #
    def self.wpautop(pee, br = true)
      return "" if pee.nil? || pee.strip == ""

      allblocks = %r{(?:table|thead|tfoot|caption|col|colgroup|tbody|tr|td|th|div|dl|dd|dt|ul|ol|li|pre|select|option|form|map|area|blockquote|address|math|style|p|h[1-6]|hr|fieldset|noscript|legend|section|article|aside|hgroup|header|footer|nav|figure|figcaption|details|menu|summary)}i
      pre_tags = {}
      pee += "\n"

      if pee.include?("<pre")
        pee_parts = pee.split("</pre>")
        last_pee = pee_parts.pop
        pee = ""
        pee_parts.each_with_index do |pee_part, i|
          start = pee_part.index("<pre")

          unless start
            pee += pee_part
            next
          end

          name = "<pre wp-pre-tag-#{i}></pre>"
          pre_tags[name] = (pee_part[start..-1] + "</pre>").gsub('\\', '\\\\\\\\')

          pee += pee_part[0, start] + name
        end
        pee += last_pee
      end

      pee = pee.gsub(Regexp.new('<br />\\s*<br />'), "\n\n")
      pee = pee.gsub(Regexp.new("(<#{allblocks}[^>]*>)"), "\n\\1")
      pee = pee.gsub(Regexp.new("(</#{allblocks}>)"), "\\1\n\n")
      pee = pee.gsub("\r\n", "\n").tr("\r", "\n")
      if pee.include? "<object"
        pee = pee.gsub(Regexp.new('\s*<param([^>]*)>\s*'), "<param\\1>")
        pee = pee.gsub(Regexp.new('\s*</embed>\s*'), "</embed>")
      end

      pees = pee.split(%r!\n\s*\n!).compact
      pee = ""
      pees.each { |tinkle| pee += "<p>" + tinkle.chomp("\n") + "</p>\n" }
      pee = pee.gsub(Regexp.new('<p>\s*</p>'), "")
      pee = pee.gsub(Regexp.new("<p>([^<]+)</(div|address|form)>"), "<p>\\1</p></\\2>")
      pee = pee.gsub(Regexp.new('<p>\s*(</?' + allblocks + '[^>]*>)\s*</p>'), "\\1")
      pee = pee.gsub(Regexp.new("<p>(<li.+?)</p>"), "\\1")
      pee = pee.gsub(Regexp.new("<p><blockquote([^>]*)>", "i"), "<blockquote\\1><p>")
      pee = pee.gsub("</blockquote></p>", "</p></blockquote>")
      pee = pee.gsub(Regexp.new('<p>\s*(</?' + allblocks + "[^>]*>
