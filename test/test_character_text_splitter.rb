require 'minitest/unit'
require 'baran'

MiniTest::Unit.autorun

class TestCharacterTextSplitter < MiniTest::Unit::TestCase
  def setup
    @splitter = Baran::CharacterTextSplitter.new(chunk_size: 10, chunk_overlap: 5)
  end

  def test_chunks
    chunks = @splitter.chunks("Hello, world!\n\nHello, world!\n\nHello, world!")

    assert_equal(chunks.length, 3)
  end

  def test_with_regexp_separator
    separator = Regexp.new('== (?:Page )?\\d+ ==')
    text = <<~TEXT
      == Page 1 ==
      Hello, world!\n\n
      == Page 2 ==
      Hello, world!\n\n
      == Page 3 ==
      Hello, world!
    TEXT
    expected_chunk_1 = "== Page 1 ==\nHello, world!"
    @splitter = Baran::CharacterTextSplitter.new(
      chunk_size: 10, chunk_overlap: 0, separator: separator)
    chunks = @splitter.chunks(text)
    assert_equal(chunks.length, 3)
    assert_equal(chunks[0][:text], expected_chunk_1)
  end
end
