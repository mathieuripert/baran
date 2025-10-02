require 'logger'

module Baran
  class TextSplitter
    attr_accessor :chunk_size, :chunk_overlap, :token_count_fn

    def initialize(chunk_size: 1024, chunk_overlap: 64, token_count_fn: nil)
      @chunk_size = chunk_size
      @chunk_overlap = chunk_overlap
      @token_count_fn = token_count_fn
      raise "Cannot have chunk_overlap >= chunk_size" if @chunk_overlap >= @chunk_size
    end

    def splitted(text)
      raise NotImplementedError, "splitted method should be implemented in a subclass"
    end

    def chunks(text, metadata: nil)
      cursor = 0
      chunks = []

      splitted(text).compact.each do |chunk|
        chunk = { text: chunk, cursor: cursor }
        chunk[:metadata] = metadata if metadata
        chunks << chunk
        cursor += chunk[:text].length
      end

      chunks
    end

    def joined(items, separator)
      separator_str = separator.is_a?(Regexp) ? "\n" : separator
      text = items.join(separator_str).strip
      text.empty? ? nil : text
    end

    def token_count(text)
      if @token_count_fn
        @token_count_fn.call(text)
      else
        text.length
      end
    end

    def detect_markdown_tables(text)
      # Find all markdown tables in the text
      tables = []
      lines = text.split("\n")
      
      i = 0
      while i < lines.length
        line = lines[i]
        
        # Check if this line looks like a table header (contains |)
        if line.strip.match?(/^\|.*\|$/) || line.strip.match?(/^[^|]*\|.*\|[^|]*$/)
          # Look for the separator line (next line with dashes and pipes)
          if i + 1 < lines.length && lines[i + 1].strip.match?(/^[\|\-\s:]+$/)
            # Found a table! Collect all consecutive table rows
            table_start = i
            table_lines = [lines[i], lines[i + 1]] # header and separator
            
            j = i + 2
            while j < lines.length
              next_line = lines[j]
              if next_line.strip.match?(/^\|.*\|$/) || next_line.strip.match?(/^[^|]*\|.*\|[^|]*$/)
                table_lines << next_line
                j += 1
              else
                break
              end
            end
            
            # Calculate positions in original text
            text_before_table = lines[0...table_start].join("\n")
            start_pos = text_before_table.length + (table_start > 0 ? 1 : 0) # +1 for newline
            table_text = table_lines.join("\n")
            end_pos = start_pos + table_text.length
            
            tables << {
              start: start_pos,
              end: end_pos,
              text: table_text
            }
            
            i = j
          else
            i += 1
          end
        else
          i += 1
        end
      end
      
      tables
    end

    def split_with_separator_preservation(text, separator)
      if separator.is_a?(Regexp)
        # For regexp separators, preserve the separator in the chunks
        parts = text.split(separator)
        matches = text.scan(separator)
        
        splits = []
        
        # First part (before any separator)
        if parts.length > 0 && !parts[0].empty?
          splits << parts[0]
        end
        
        # Remaining parts with their separators
        matches.each_with_index do |match, i|
          part_index = i + 1
          if part_index < parts.length
            # Reconstruct the chunk with the separator (remove leading \n)
            chunk = match.gsub(/^\n/, '') + parts[part_index]
            splits << chunk unless chunk.empty?
          end
        end
        
        splits
      else
        # For string separators, use standard split
        if separator.empty?
          text.chars
        else
          text.split(separator)
        end
      end
    end

    def merged(splits, separator)
      results = [] # Array of strings
      current_splits = [] # Array of strings
      total = 0

      splits.each do |split|
        split_token_count = token_count(split)
        
        # Check if this split contains a markdown table
        tables = detect_markdown_tables(split)
        contains_table = tables.any?
        
        if total + split_token_count >= chunk_size && current_splits.length.positive?
          # If the current split contains a table, don't split it
          if contains_table
            # Finish the current chunk and start a new one with the table
            results << joined(current_splits, separator) unless current_splits.empty?
            results << split
            current_splits = []
            total = 0
            next
          else
            results << joined(current_splits, separator)

            while total > chunk_overlap || (total + split_token_count >= chunk_size && total.positive?)
              total -= token_count(current_splits.first)
              current_splits.shift
            end
          end
        end

        # If this split contains a table and would make the chunk too big, 
        # finish current chunk and put table in its own chunk
        if contains_table && total > 0 && total + split_token_count > chunk_size
          results << joined(current_splits, separator) unless current_splits.empty?
          results << split
          current_splits = []
          total = 0
        else
          current_splits << split
          total += split_token_count
          Logger.new(STDOUT).warn("Created a chunk of size #{total}, which is longer than the specified #{@chunk_size}") if total > @chunk_size
        end
      end

      results << joined(current_splits, separator) unless current_splits.empty?

      results
    end
  end
end
