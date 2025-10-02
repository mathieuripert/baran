#!/usr/bin/env ruby
# Helper script to regenerate output files for integration testing

require_relative '../lib/baran'
require_relative 'test_markdown_splitter_integration'

# Regenerate all output files
puts "Discovering test files..."
test_files = TestMarkdownSplitterIntegration.discover_test_files

if test_files.empty?
  puts "No markdown files found in test/data/"
  exit 1
end

puts "Found #{test_files.length} test file(s):"
test_files.each { |tc| puts "  - #{tc[:name]} (#{tc[:input_file]})" }

puts "\nRegenerating output files..."
TestMarkdownSplitterIntegration.regenerate_all_output_files

puts "\n✅ All output files regenerated successfully!"
