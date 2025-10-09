# frozen_string_literal: true

require_relative './text_splitter'

module Baran
  class RecursiveCharacterTextSplitter < TextSplitter
    attr_accessor :separators

    def initialize(chunk_size: 1024, chunk_overlap: 64, separators: nil, token_count_fn: nil)
      super(chunk_size: chunk_size, chunk_overlap: chunk_overlap, token_count_fn: token_count_fn)
      @separators = separators || ["\n\n", "\n", ' ']
    end

    def splitted(text)
      results = []
      good_splits = []
      separator = ''

      # NOTE: We used to have special table handling here, but now we let tables
      # flow through the normal splitting and merging process to allow them to
      # merge with other content when they fit within chunk_size

      # Find the first separator that matches
      separators.each do |s|
        if s.is_a?(Regexp)
          if text.match?(s)
            separator = s
            break
          end
        elsif s.is_a?(String) && text.include?(s)
          separator = s
          break
        end
      end

      # If no separator was found and character-level splitting is not in separators,
      # preserve semantic integrity by returning text as-is
      return [text] if separator == '' && separators.none? { |s| s.is_a?(String) && s == '' }

      splits = split_with_separator_preservation(text, separator)

      # Check if we made meaningful progress in splitting
      # If we only got one split back and it's the same as input, try next separator
      if splits.length == 1 && splits[0] == text
        # This separator didn't actually split the text, try the next one
        remaining_separators = separators[(separators.index(separator) + 1)..]
        return [text] unless remaining_separators.any?

        # Try with remaining separators
        temp_splitter = RecursiveCharacterTextSplitter.new(
          chunk_size: chunk_size,
          chunk_overlap: chunk_overlap,
          separators: remaining_separators,
          token_count_fn: token_count_fn
        )
        return temp_splitter.splitted(text)

        # No more separators to try, return as-is

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
            # Use remaining separators for recursion (skip the one we just used)
            remaining_separators = separators[(separators.index(separator) + 1)..]
            if remaining_separators.any?
              # Only create RecursiveCharacterTextSplitter for recursion
              temp_splitter = RecursiveCharacterTextSplitter.new(
                chunk_size: chunk_size,
                chunk_overlap: chunk_overlap,
                separators: remaining_separators,
                token_count_fn: token_count_fn
              )
              results += temp_splitter.splitted(s)
            else
              # No more separators, keep as single chunk
              results << s
            end
          else
            # Can't split further, keep as single chunk even if oversized
            results << s
          end
        end
      end

      results += merged(good_splits, separator) if good_splits.length.positive?

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
          unless before_table.empty?
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
        after_tables = text[current_pos..].strip
        results += splitted(after_tables) unless after_tables.empty?
      end

      results
    end
  end
end
