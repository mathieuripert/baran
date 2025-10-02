require 'minitest/unit'
require 'baran'
require 'json'

MiniTest::Unit.autorun

class TestMarkdownSplitterIntegration < MiniTest::Unit::TestCase
  CHUNKS_FILE = 'test/data/expected_chunks.json'
  INPUT_FILE = 'test/data/input_text.md'
  
  def setup
    @text = File.read(INPUT_FILE)
    @splitter = Baran::MarkdownSplitter.new(chunk_size: 400, chunk_overlap: 50)
  end

  def test_document_processing
    chunks = @splitter.chunks(@text)
    
    # Basic document processing assertions
    assert chunks.length > 0, "Should generate chunks"
    assert_equal 4806, @text.length, "Document should have expected length"
    
    # Verify chunks have required structure
    chunks.each_with_index do |chunk, i|
      assert chunk.key?(:text), "Chunk #{i} should have text"
      assert chunk.key?(:cursor), "Chunk #{i} should have cursor position"
      assert chunk[:text].length > 0, "Chunk #{i} should have non-empty text"
    end
  end

  def test_table_protection
    chunks = @splitter.chunks(@text)
    
    # Find table chunk
    table_chunk = chunks.find { |chunk| chunk[:text].include?('| Quarter | Revenue') }
    
    assert table_chunk, "Should find table chunk"
    
    # Verify complete table is in one chunk
    table_text = table_chunk[:text]
    assert table_text.include?('| Quarter | Revenue (M$) | Growth % | Operating Margin % | Net Income (M$) |')
    assert table_text.include?('| Q1 2024 | 650          | 32%      | 26%               | 169             |')
    assert table_text.include?('| Q2 2024 | 720          | 38%      | 28%               | 202             |')
    assert table_text.include?('| Q3 2024 | 695          | 33%      | 27%               | 188             |')
    assert table_text.include?('| Q4 2024 | 735          | 37%      | 30%               | 221             |')
    
    # Verify table is preserved despite exceeding chunk size
    assert table_text.length > 400, "Table chunk should exceed normal chunk size limit"
    
    # Verify no other chunks contain partial table rows
    other_chunks = chunks.reject { |chunk| chunk == table_chunk }
    other_chunks.each do |chunk|
      assert !chunk[:text].include?('| Q1 2024'), "Table row should not be split across chunks"
      assert !chunk[:text].include?('| Q2 2024'), "Table row should not be split across chunks"
      assert !chunk[:text].include?('| Q3 2024'), "Table row should not be split across chunks"
      assert !chunk[:text].include?('| Q4 2024'), "Table row should not be split across chunks"
    end
  end

  def test_chunk_consistency_with_expected_output
    # Skip this test if expected chunks file doesn't exist
    return unless File.exist?(CHUNKS_FILE)
    
    chunks = @splitter.chunks(@text)
    
    begin
      expected_data = JSON.parse(File.read(CHUNKS_FILE))
      expected_chunks = expected_data['chunks']
      
      assert_equal expected_chunks.length, chunks.length, "Should generate same number of chunks as expected"
      
      # Compare each chunk
      chunks.each_with_index do |chunk, i|
        expected_chunk = expected_chunks[i]
        assert_equal expected_chunk['text'], chunk[:text], "Chunk #{i} text should match expected"
        assert_equal expected_chunk['cursor'], chunk[:cursor], "Chunk #{i} cursor should match expected"
        assert_equal expected_chunk['length'], chunk[:text].length, "Chunk #{i} length should match expected"
      end
      
      # Verify table chunk is consistently identified
      table_chunks_count = chunks.count { |chunk| chunk[:text].include?('| Quarter | Revenue') }
      expected_table_chunks = expected_chunks.count { |chunk| chunk['contains_table'] }
      assert_equal expected_table_chunks, table_chunks_count, "Should have same number of table chunks"
      
    rescue JSON::ParserError => e
      flunk "Could not parse expected chunks file: #{e.message}"
    end
  end

  def test_header_structure_preservation
    chunks = @splitter.chunks(@text)
    
    # Verify main headers are preserved
    main_header_chunk = chunks.find { |chunk| chunk[:text].include?('# TechCorp Industries Annual Report 2024') }
    assert main_header_chunk, "Should preserve main header"
    
    # Verify section headers are preserved with their content
    executive_summary_chunk = chunks.find { |chunk| chunk[:text].include?('## Executive Summary') }
    assert_not_nil executive_summary_chunk, "Should find executive summary section"
    
    # Verify subsection headers
    key_highlights_chunk = chunks.find { |chunk| chunk[:text].include?('### Key Highlights') }
    assert_not_nil key_highlights_chunk, "Should find key highlights subsection"
  end

  def test_chunk_size_limits
    chunks = @splitter.chunks(@text)
    
    # Most chunks should respect the size limit (except tables)
    oversized_chunks = chunks.select { |chunk| chunk[:text].length > 450 } # Allow some buffer
    
    # Should only have the table chunk as oversized
    assert oversized_chunks.length <= 2, "Should have at most 2 oversized chunks (table + possible overlap)"
    
    # Verify the oversized chunk is indeed the table chunk
    table_chunk = oversized_chunks.find { |chunk| chunk[:text].include?('| Quarter | Revenue') }
    assert_not_nil table_chunk, "Oversized chunk should be the table chunk"
  end

  # Helper method to regenerate expected chunks file (for development)
  def regenerate_expected_chunks_file
    chunks = @splitter.chunks(@text)
    
    chunks_data = {
      metadata: {
        document_length: @text.length,
        chunk_count: chunks.length,
        chunk_size: 400,
        chunk_overlap: 50,
        generated_at: Time.now.to_s
      },
      chunks: chunks.map.with_index do |chunk, i|
        {
          index: i,
          text: chunk[:text],
          cursor: chunk[:cursor],
          length: chunk[:text].length,
          contains_table: chunk[:text].include?('| Quarter | Revenue')
        }
      end
    }
    
    File.write(CHUNKS_FILE, JSON.pretty_generate(chunks_data))
    puts "Regenerated expected chunks file: #{CHUNKS_FILE}"
  end
end
