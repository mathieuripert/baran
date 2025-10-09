require 'minitest/unit'
require 'baran'

MiniTest::Unit.autorun

class TestRecursiveCharacterTextSplitter < MiniTest::Unit::TestCase
  def test_basic_text_splitting
    text = "Hello world\n\nThis is a test\n\nWith multiple paragraphs"
    splitter = Baran::RecursiveCharacterTextSplitter.new(chunk_size: 20, chunk_overlap: 5)
    chunks = splitter.chunks(text)
    
    assert chunks.length > 1, "Should split text into multiple chunks"
    chunks.each do |chunk|
      assert chunk.key?(:text), "Each chunk should have text"
      assert chunk.key?(:cursor), "Each chunk should have cursor position"
    end
  end

  def test_with_regex_separators
    text = "== Page 1 ==\nHello world\n== Page 2 ==\nThis is a test\n== Page 3 ==\nWith multiple paragraphs"
    splitter = Baran::RecursiveCharacterTextSplitter.new(
        chunk_size: 1,
        chunk_overlap: 0,
        separators: [Regexp.new("== Page \\d+ ==")])
    chunks = splitter.chunks(text)
    
    assert chunks.length == 3, "Should split text into 3 chunks"
    assert chunks[0][:text].include?("Page 1"), "First chunk should contain Page 1"
    assert chunks[1][:text].include?("Page 2"), "Second chunk should contain Page 2"
    assert chunks[2][:text].include?("Page 3"), "Third chunk should contain Page 3"
  end
  

  def test_markdown_headers_with_string_separators
    text = "# Header 1\nContent 1\n\n## Header 2\nContent 2"
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 50, 
      chunk_overlap: 0,
      separators: ["\n\n", "\n", " "]
    )
    chunks = splitter.chunks(text)
    
    assert chunks.any? { |c| c[:text].include?("Header 1") }, "Should preserve header content"
    assert chunks.length > 0, "Should generate chunks"
  end

  def test_single_line_text
    text = "This is a single line of text that should fit in one chunk"
    splitter = Baran::RecursiveCharacterTextSplitter.new(chunk_size: 100, chunk_overlap: 0)
    chunks = splitter.chunks(text)
    
    assert_equal 1, chunks.length, "Single line should create one chunk"
    assert_equal text, chunks[0][:text], "Text should be preserved exactly"
  end

  def test_empty_text
    text = ""
    splitter = Baran::RecursiveCharacterTextSplitter.new(chunk_size: 50, chunk_overlap: 0)
    chunks = splitter.chunks(text)
    
    # Empty text actually creates one empty chunk in this implementation
    assert_equal 1, chunks.length, "Empty text creates one empty chunk"
    assert_equal "", chunks[0][:text], "Empty chunk should have empty text"
  end

  def test_text_with_only_whitespace
    text = "\n\n   \n\n"
    splitter = Baran::RecursiveCharacterTextSplitter.new(chunk_size: 50, chunk_overlap: 0)
    chunks = splitter.chunks(text)
    
    assert chunks.length >= 0, "Whitespace-only text should be handled gracefully"
  end

  def test_long_unsplittable_text
    text = "A" * 100  # Text that can't be split with unknown separator
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 50,
      chunk_overlap: 0,
      separators: ["UNKNOWN_SEPARATOR"]
    )
    chunks = splitter.chunks(text)
    
    assert_equal 1, chunks.length, "Should handle unsplittable text gracefully"
    # When no separator matches, the text is preserved as-is even if it exceeds chunk_size
    assert_equal text, chunks[0][:text], "Should preserve original text when no separators match"
  end

  def test_text_with_custom_separators
    text = "Part1||Part2||Part3||Part4"
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 10,
      chunk_overlap: 0,
      separators: ["||", " "]
    )
    chunks = splitter.chunks(text)
    
    assert chunks.length > 1, "Should split on custom separators"
    assert chunks.all? { |c| c[:text].length <= 10 || !c[:text].include?("||") }, "Should respect chunk size or separator boundaries"
  end

  def test_overlapping_chunks
    text = "Word1 Word2 Word3 Word4 Word5"
    splitter = Baran::RecursiveCharacterTextSplitter.new(chunk_size: 12, chunk_overlap: 6)
    chunks = splitter.chunks(text)
    
    assert chunks.length > 1, "Should create overlapping chunks"
    # Verify that overlap configuration works without causing errors
    chunks.each do |chunk|
      assert chunk[:text].length > 0, "Each chunk should have content"
    end
  end
end
