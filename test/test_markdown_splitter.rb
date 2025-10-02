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
end
