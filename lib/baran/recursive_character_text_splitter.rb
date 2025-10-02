require_relative './text_splitter'

module Baran
  class RecursiveCharacterTextSplitter < TextSplitter
    attr_accessor :separators

    def initialize(chunk_size: 1024, chunk_overlap: 64, separators: nil, token_count_fn: nil)
      super(chunk_size: chunk_size, chunk_overlap: chunk_overlap, token_count_fn: token_count_fn)
      @separators = separators || ["\n\n", "\n", " "]
    end

    def splitted(text)
      results = []
      good_splits = []
      separator = ''

      # First, check if the text contains markdown tables
      tables = detect_markdown_tables(text)
      
      # If text contains tables and is larger than chunk_size, handle specially
      if tables.any? && token_count(text) >= chunk_size
        return handle_text_with_tables(text, tables)
      end

      separators.each do |s|
        if s.is_a?(Regexp)
          if text.match?(s)
            separator = s
            break
          end
        else
          if text.include?(s)
            separator = s
            break
          end
        end
      end

      splits = split_with_separator_preservation(text, separator)
      
      splits.each do |s|
        if token_count(s) < chunk_size
          good_splits << s
        else
          if good_splits.length.positive?
            results += merged(good_splits, separator)
            good_splits.clear
          end
          results += splitted(s)
        end
      end

      if good_splits.length.positive?
        results += merged(good_splits, separator)
      end

      results
    end

    private

    def handle_text_with_tables(text, tables)
      results = []
      current_pos = 0
      
      tables.each do |table|
        # Add text before the table
        if table[:start] > current_pos
          before_table = text[current_pos...table[:start]].strip
          if !before_table.empty?
            # Recursively split the text before the table
            results += splitted(before_table)
          end
        end
        
        # Add the complete table as a single chunk
        results << table[:text]
        current_pos = table[:end]
      end
      
      # Add any remaining text after the last table
      if current_pos < text.length
        after_tables = text[current_pos..-1].strip
        if !after_tables.empty?
          results += splitted(after_tables)
        end
      end
      
      results
    end
  end
end