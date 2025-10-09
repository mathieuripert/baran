# frozen_string_literal: true

require 'minitest/unit'
require_relative '../lib/baran'

MiniTest::Unit.autorun

class TestRecursiveCharacterTextSplitter < MiniTest::Unit::TestCase
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
      == Page 2 ==
      This is a test
      == Page 3 ==
      With multiple paragraphs
    TEXT
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 1,
      chunk_overlap: 0,
      separators: [
        Regexp.new('== Page \\d+ =='),
        /\n# / # h1
      ]
    )
    chunks = splitter.chunks(text)
    puts "Chunks: #{chunks.size}"
    chunks.each_with_index do |chunk, i|
      puts "Chunk #{i + 1} (#{chunk[:text].length} chars): #{chunk[:text].inspect}"
    end
    assert chunks.length == 4
  end
end
