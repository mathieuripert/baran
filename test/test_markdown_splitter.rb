require 'minitest/unit'
require 'baran'

MiniTest::Unit.autorun

class TestMarkdownSplitter < MiniTest::Unit::TestCase
  def setup
    @splitter = Baran::MarkdownSplitter.new
  end

  def test_chunks
    text = <<~MARKDOWN
# Main Heading
Content for main heading.

## Section 2
Content for section 2.

### Subsection
Content for subsection.

---

Final content.
MARKDOWN

    @splitter = Baran::MarkdownSplitter.new(chunk_size: 50, chunk_overlap: 5)
    chunks = @splitter.chunks(text)

    # Should split at each header and preserve the header markers
    assert_equal(4, chunks.length)
    assert_equal("# Main Heading\nContent for main heading.", chunks[0][:text])
    assert_equal("## Section 2\nContent for section 2.", chunks[1][:text])
    assert_equal("### Subsection\nContent for subsection.", chunks[2][:text])
    assert_equal("---\nFinal content.", chunks[3][:text])
  end

  def test_markdown_table_not_split
    text = <<~MARKDOWN
# Data Analysis

Here's our data:

| Name    | Age | City      |
|---------|-----|-----------|
| Alice   | 25  | New York  |
| Bob     | 30  | London    |
| Charlie | 35  | Paris     |

## Summary

The table shows user data.
MARKDOWN

    # Use a small chunk size that would normally split the table
    @splitter = Baran::MarkdownSplitter.new(chunk_size: 32, chunk_overlap: 0)
    chunks = @splitter.chunks(text)

    # The table should not be split - it should stay as one complete chunk
    table_chunk = chunks.find { |chunk| chunk[:text].include?("| Name") }
    
    # Verify the entire table is in one chunk
    assert table_chunk, "Table chunk should exist"
    assert table_chunk[:text].include?("| Name    | Age | City      |")
    assert table_chunk[:text].include?("|---------|-----|-----------|")
    assert table_chunk[:text].include?("| Alice   | 25  | New York  |")
    assert table_chunk[:text].include?("| Bob     | 30  | London    |")
    assert table_chunk[:text].include?("| Charlie | 35  | Paris     |")
    
    # Verify no other chunk contains partial table rows
    other_chunks = chunks.reject { |chunk| chunk == table_chunk }
    other_chunks.each do |chunk|
      assert !chunk[:text].include?("| Alice"), "Table row should not be split across chunks"
      assert !chunk[:text].include?("| Bob"), "Table row should not be split across chunks"
      assert !chunk[:text].include?("| Charlie"), "Table row should not be split across chunks"
    end
  end
end
