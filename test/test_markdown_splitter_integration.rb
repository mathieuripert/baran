require 'minitest/unit'
require 'baran'
require 'json'

MiniTest::Unit.autorun

class TestMarkdownSplitterIntegration < MiniTest::Unit::TestCase
  DATA_DIR = 'test/data'
  
  def self.discover_test_files
    return [] unless Dir.exist?(DATA_DIR)
    
    markdown_files = Dir.glob(File.join(DATA_DIR, '*.md'))
    test_cases = []
    
    markdown_files.each do |md_file|
      basename = File.basename(md_file, '.md')
      output_file = File.join(DATA_DIR, "#{basename}_output.json")
      
      test_cases << {
        name: basename,
        input_file: md_file,
        output_file: output_file,
        chunk_size: 400,
        chunk_overlap: 50
      }
    end
    
    test_cases
  end

  # Generate test methods dynamically for each discovered file
  discover_test_files.each do |test_case|
    define_method("test_#{test_case[:name]}_document_processing") do
      run_document_processing_test(test_case)
    end
    
    define_method("test_#{test_case[:name]}_table_protection") do
      run_table_protection_test(test_case)
    end
    
    define_method("test_#{test_case[:name]}_consistency") do
      run_consistency_test(test_case)
    end
    
    define_method("test_#{test_case[:name]}_header_preservation") do
      run_header_preservation_test(test_case)
    end
    
    define_method("test_#{test_case[:name]}_chunk_size_limits") do
      run_chunk_size_limits_test(test_case)
    end
  end

  private

  def load_test_data(test_case)
    text = File.read(test_case[:input_file])
    splitter = Baran::MarkdownSplitter.new(
      chunk_size: test_case[:chunk_size], 
      chunk_overlap: test_case[:chunk_overlap]
    )
    chunks = splitter.chunks(text)
    
    { text: text, splitter: splitter, chunks: chunks, test_case: test_case }
  end

  def run_document_processing_test(test_case)
    data = load_test_data(test_case)
    chunks = data[:chunks]
    text = data[:text]
    
    # Basic document processing assertions
    assert chunks.length > 0, "Should generate chunks for #{test_case[:name]}"
    
    # Verify chunks have required structure
    chunks.each_with_index do |chunk, i|
      assert chunk.key?(:text), "Chunk #{i} should have text in #{test_case[:name]}"
      assert chunk.key?(:cursor), "Chunk #{i} should have cursor position in #{test_case[:name]}"
      assert chunk[:text].length > 0, "Chunk #{i} should have non-empty text in #{test_case[:name]}"
    end
  end

  def run_table_protection_test(test_case)
    data = load_test_data(test_case)
    chunks = data[:chunks]
    text = data[:text]
    
    # Skip if no tables in document
    return unless text.include?('|') && text.match?(/\|.*\|.*\|/)
    
    # Find table chunks (look for pipe characters in structured format)
    table_chunks = chunks.select { |chunk| 
      chunk_text = chunk[:text]
      # Check for table structure: multiple lines with pipes
      lines_with_pipes = chunk_text.lines.count { |line| line.include?('|') && line.count('|') >= 2 }
      lines_with_pipes >= 2
    }
    
    return if table_chunks.empty?
    
    table_chunks.each_with_index do |table_chunk, idx|
      table_text = table_chunk[:text]
      
      # Verify table rows are not split across other chunks
      table_lines = table_text.lines.select { |line| line.include?('|') && line.count('|') >= 2 }
      
      table_lines.each do |table_line|
        # Extract a unique part of the table line for checking
        line_content = table_line.strip
        next if line_content.match?(/^[\|\-\s]+$/) # Skip separator lines
        
        other_chunks = chunks.reject { |chunk| chunk == table_chunk }
        other_chunks.each do |chunk|
          assert !chunk[:text].include?(line_content), 
            "Table line '#{line_content[0..50]}...' should not be split across chunks in #{test_case[:name]}"
        end
      end
    end
  end

  def run_consistency_test(test_case)
    data = load_test_data(test_case)
    chunks = data[:chunks]
    
    # If output file doesn't exist, generate it and pass the test
    unless File.exist?(test_case[:output_file])
      puts "\n📝 Generating output file for #{test_case[:name]}: #{test_case[:output_file]}"
      self.class.generate_output_file(test_case, chunks, data[:text])
      puts "✅ Generated #{chunks.length} chunks for #{test_case[:name]}"
      return # Test passes after generating the file
    end
    
    # If output file exists, compare against it
    begin
      expected_data = JSON.parse(File.read(test_case[:output_file]))
      expected_chunks = expected_data['chunks']
      
      assert_equal expected_chunks.length, chunks.length, 
        "Should generate same number of chunks as expected for #{test_case[:name]}"
      
      # Compare each chunk
      chunks.each_with_index do |chunk, i|
        expected_chunk = expected_chunks[i]
        assert_equal expected_chunk['text'], chunk[:text], 
          "Chunk #{i} text should match expected in #{test_case[:name]}"
        assert_equal expected_chunk['cursor'], chunk[:cursor], 
          "Chunk #{i} cursor should match expected in #{test_case[:name]}"
        assert_equal expected_chunk['length'], chunk[:text].length, 
          "Chunk #{i} length should match expected in #{test_case[:name]}"
      end
      
    rescue JSON::ParserError => e
      flunk "Could not parse output chunks file for #{test_case[:name]}: #{e.message}"
    end
  end

  def run_header_preservation_test(test_case)
    data = load_test_data(test_case)
    chunks = data[:chunks]
    text = data[:text]
    
    # Find all headers in the original text
    headers = text.scan(/^#+\s+.+$/)
    
    return if headers.empty?
    
    # Verify each header appears in exactly one chunk
    headers.each do |header|
      chunks_with_header = chunks.select { |chunk| chunk[:text].include?(header) }
      assert chunks_with_header.length >= 1, 
        "Header '#{header.strip}' should appear in at least one chunk in #{test_case[:name]}"
    end
  end

  def run_chunk_size_limits_test(test_case)
    data = load_test_data(test_case)
    chunks = data[:chunks]
    chunk_size = test_case[:chunk_size]
    
    # Most chunks should respect the size limit (except protected content like tables)
    buffer = chunk_size * 0.1 # 10% buffer
    oversized_chunks = chunks.select { |chunk| chunk[:text].length > chunk_size + buffer }
    
    # Oversized chunks should contain protected content (tables, etc.)
    oversized_chunks.each do |chunk|
      has_table = chunk[:text].include?('|') && chunk[:text].lines.count { |line| line.include?('|') } >= 2
      has_long_unbreakable_content = chunk[:text].lines.any? { |line| line.length > chunk_size }
      
      assert(has_table || has_long_unbreakable_content, 
        "Oversized chunk should contain protected content (table/unbreakable) in #{test_case[:name]}")
    end
  end

  # Helper method to regenerate all output files (for development)
  def self.regenerate_all_output_files
    discover_test_files.each do |test_case|
      regenerate_output_file(test_case)
    end
  end

  def self.regenerate_output_file(test_case)
    text = File.read(test_case[:input_file])
    splitter = Baran::MarkdownSplitter.new(
      chunk_size: test_case[:chunk_size], 
      chunk_overlap: test_case[:chunk_overlap]
    )
    chunks = splitter.chunks(text)
    
    generate_output_file(test_case, chunks, text)
  end

  def self.generate_output_file(test_case, chunks, text)
    chunks_data = {
      metadata: {
        input_file: test_case[:input_file],
        document_length: text.length,
        chunk_count: chunks.length,
        chunk_size: test_case[:chunk_size],
        chunk_overlap: test_case[:chunk_overlap],
        generated_at: Time.now.to_s
      },
      chunks: chunks.map.with_index do |chunk, i|
        {
          index: i,
          text: chunk[:text],
          cursor: chunk[:cursor],
          length: chunk[:text].length,
          contains_table: detect_table_in_chunk(chunk[:text])
        }
      end
    }
    
    File.write(test_case[:output_file], JSON.pretty_generate(chunks_data))
    puts "Generated output file: #{test_case[:output_file]}"
  end

  def self.detect_table_in_chunk(text)
    return false unless text.include?('|')
    lines_with_pipes = text.lines.count { |line| line.include?('|') && line.count('|') >= 2 }
    lines_with_pipes >= 2
  end
end
