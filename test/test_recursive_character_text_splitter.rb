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
    # Simple test document with multiple sections and tables
    text = <<~TEXT
== Section 1 ==

Introduction to our test document.

== Section 2 ==

# Main Content

Here is some content before our first table.

| Item | Quantity | Price |
|------|----------|-------|
| Apple | 10 | $5.00 |
| Banana | 15 | $3.00 |
| Orange | 8 | $4.00 |

This text comes after the first table.

== Section 3 ==

## Product Categories

More descriptive text about products.

| Category | Count |
|----------|-------|
| Fruits | 25 |
| Vegetables | 18 |

Additional content after the second table.

== Section 4 ==

### Summary

| Metric | Value |
|--------|-------|
| Total Items | 43 |
| Revenue | $95.00 |

Final summary text here.

== Section 5 ==

Conclusion of the document.
TEXT

    # Use standard separators including page breaks
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 1024,
      chunk_overlap: 0,
      separators: [/== (?:Section )?\d+ ==/, /\n# /, /\n## /, /\n### /, "\n\n", "\n", " ", ""]
    )
    
    chunks = splitter.chunks(text)
    
    puts "Text length: #{text.length} chars"
    puts "Generated #{chunks.length} chunks with chunk_size=1024:"
    chunks.each_with_index do |chunk, i|
      puts "\nChunk #{i+1} (#{chunk[:text].length} chars):"
      puts "Contains table: #{chunk[:text].include?('|')}"
      puts "First 80 chars: #{chunk[:text][0..80].inspect}..."
    end
    
    # Check if any tables are isolated (table-only chunks)
    table_chunks = chunks.select { |c| c[:text].include?('|') }
    isolated_tables = table_chunks.select do |chunk|
      text = chunk[:text].strip
      # Check if chunk is mostly just table content (no substantial other text)
      lines = text.split("\n")
      table_lines = lines.count { |line| line.include?('|') }
      non_table_lines = lines.count { |line| !line.include?('|') && line.strip.length > 5 }
      table_lines > 0 && non_table_lines < 2
    end
    
    puts "\nTable analysis:"
    puts "Total chunks with tables: #{table_chunks.length}"
    puts "Isolated table chunks: #{isolated_tables.length}"
    
    # Basic assertions
    assert chunks.length > 0, "Should generate at least one chunk"
    
    # The main test: tables should NOT be isolated when they can merge with other content
    # With chunk_size=1024, tables should be able to merge with surrounding text
    assert_equal 0, isolated_tables.length, "Tables should not be isolated when they can merge with other content"
    
    # Verify that tables are preserved
    all_text = chunks.map { |c| c[:text] }.join("\n")
    assert all_text.include?("| Item | Quantity | Price |"), "Should preserve table headers"
    assert all_text.include?("| Apple | 10 | $5.00 |"), "Should preserve table content"
  end
end
