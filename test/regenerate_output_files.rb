#!/usr/bin/env ruby
# Helper script to regenerate output files for integration testing

require_relative '../lib/baran'
require 'json'

DATA_DIR = 'test/data'

def discover_test_files
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

def generate_output_file(test_case)
  text = File.read(test_case[:input_file])
  splitter = Baran::MarkdownSplitter.new(
    chunk_size: test_case[:chunk_size], 
    chunk_overlap: test_case[:chunk_overlap]
  )
  chunks = splitter.chunks(text)
  
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

def detect_table_in_chunk(text)
  return false unless text.include?('|')
  lines_with_pipes = text.lines.count { |line| line.include?('|') && line.count('|') >= 2 }
  lines_with_pipes >= 2
end

# Main execution
puts "Discovering test files..."
test_files = discover_test_files

if test_files.empty?
  puts "No markdown files found in test/data/"
  exit 1
end

puts "Found #{test_files.length} test file(s):"
test_files.each { |tc| puts "  - #{tc[:name]} (#{tc[:input_file]})" }

puts "\nRegenerating output files..."
test_files.each { |test_case| generate_output_file(test_case) }

puts "\n✅ All output files regenerated successfully!"
