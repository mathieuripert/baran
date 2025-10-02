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

      # Find the first separator that matches
      separators.each do |s|
        if s.is_a?(Regexp)
          if text.match?(s)
            separator = s
            break
          end
        else
          if s.is_a?(String) && text.include?(s)
            separator = s
            break
          end
        end
      end

      # If no separator was found and character-level splitting is not in separators,
      # preserve semantic integrity by returning text as-is
      if separator == '' && !separators.include?('')
        return [text]
      end

      splits = split_with_separator_preservation(text, separator)
      
      # Check if we made meaningful progress in splitting
      # If we only got one split back and it's the same as input, we can't split further
      if splits.length == 1 && splits[0] == text && token_count(text) >= chunk_size
        # Can't split this text with any available separators
        # Return it as-is, even if it exceeds chunk_size
        return [text]
      end
      
      splits.each do |s|
        if token_count(s) < chunk_size
          good_splits << s
        else
          if good_splits.length.positive?
            results += merged(good_splits, separator)
            good_splits.clear
          end
          
          # Only recurse if we can make progress
          # Check if this split is different from the original text
          if s != text
            results += splitted(s)
          else
            # Can't split further, keep as single chunk even if oversized
            results << s
          end
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