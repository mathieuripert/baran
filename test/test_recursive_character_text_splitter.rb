# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/baran'

class TestRecursiveCharacterTextSplitter < Minitest::Test
  def test_basic_text_splitting
    text = "Hello world\n\nThis is a test\n\nWith multiple paragraphs"
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 20,
      chunk_overlap: 5,
      separators: ["\n\n", "\n", ' ']
    )
    chunks = splitter.chunks(text)
    assert chunks.length > 1, 'Should split text into multiple chunks'
    chunks.each do |chunk|
      assert chunk.key?(:text), 'Each chunk should have text'
      assert chunk.key?(:cursor), 'Each chunk should have cursor position'
    end
  end

  def test_with_regex_separators
    text = <<~TEXT
      == Page 1 ==
      Hello world
      # 1.1
      content 1.1
      ## 1.2
      chunk 1

      chunk 2

      == Page 2 ==
      This is a test

      == Page 3 ==
      With multiple paragraphs

      == Page 4 ==
      | col 1 | col 2 | col 3 |
      |-------|-------|-------|
      | 1     | 2     | 3     |
      | 4     | 5     | 6     |
      | 7     | 8     | 9     |
    TEXT
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 1,
      chunk_overlap: 0,
      separators: [
        Regexp.new('== Page \\d+ =='),
        /\n# /, # h1,
        /\n## /, # h2,
        "\n\n"
      ]
    )
    chunks = splitter.chunks(text)
    assert chunks.length == 7
  end
end
