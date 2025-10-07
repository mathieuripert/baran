require 'minitest/unit'
require 'baran'

MiniTest::Unit.autorun

class TestRecursiveCharacterTextSplitter < MiniTest::Unit::TestCase
  def setup
    @splitter = Baran::RecursiveCharacterTextSplitter.new(chunk_size: 7, chunk_overlap: 5)
  end

  def test_chunks
    chunks = @splitter.chunks("Hello, world!\n\nHello, world!\n\nHello, world!")

    assert_equal(chunks.length, 6)
  end


  def test_empty_chunks
    chunks = @splitter.chunks("\n\nHello, world!\n\nHello, world!\n\nHello, world!")

    assert_equal(chunks.length, 6)
  end

  def test_with_regexp_separators
    separators = [
      /\n# /,
      /\n## /,
      /\n### /,
    ]
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 24, 
      chunk_overlap: 0, 
      separators: separators
    )
    text = <<~TEXT
    # Header 1
    Text 1
    ## Header 2
    Text 2
    ### Header 3
    Text 3
    TEXT
    chunks = splitter.chunks(text)
  
    # With chunk_size: 24, the algorithm splits at regexp separators and preserves them
    assert_equal(chunks.length, 3)
    assert_equal(chunks[0][:text], "# Header 1\nText 1")
    assert_equal(chunks[1][:text], "## Header 2\nText 2")
    assert_equal(chunks[2][:text], "### Header 3\nText 3")
  end

  def test_prevents_infinite_recursion
    page_separator = [Regexp.new("unknown")]

    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 64,
      chunk_overlap: 0,
      separators: [page_separator],
    )
    
    text = """
    == Page 1 ==
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. 
    Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
    == Page 2 ==
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. 
    Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
    """
    
    # This should not cause a stack overflow
    chunks = splitter.chunks(text)
    assert chunks.length == 1, "Should generate one chunk"
  end


  def test_markdown_table_merging
    # Simple test case: small table that should merge with surrounding text
    text = <<~TEXT
# Title 
Before table text.

## Table title

| Name | Age |
|------|-----|
| John | 25  |

After table text.
TEXT

    # Use a large chunk size so everything should fit in one chunk
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 200,
      chunk_overlap: 0,
      separators: [
        Regexp.new('== (?:Page )?\d+ =='),
        Regexp.new('#'),
        Regexp.new('##'),
        Regexp.new('###'),
      ]
    )
    
    chunks = splitter.chunks(text)
    
    puts "Text length: #{text.length} chars"
    puts "Generated #{chunks.length} chunks with chunk_size=200:"
    chunks.each_with_index do |chunk, i|
      puts "\nChunk #{i+1} (#{chunk[:text].length} chars):"
      puts "Text: #{chunk[:text].inspect}"
    end
    
    # Test expectation: With chunk_size=200, everything should fit in 1 chunk
    # Tables should NOT be isolated when they can merge with other content
    assert_equal 1, chunks.length, "Expected 1 chunk since total text (#{text.length} chars) fits in chunk_size (200)"
    
    # Verify the single chunk contains both table and other content
    chunk_text = chunks[0][:text]
    assert chunk_text.include?('|'), "Chunk should contain table"
    assert chunk_text.include?('Before table'), "Chunk should contain text before table"
    assert chunk_text.include?('After table'), "Chunk should contain text after table"
  end
end
