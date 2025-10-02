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
end
