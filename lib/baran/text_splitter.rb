# frozen_string_literal: true

require 'logger'

module Baran
  class TextSplitter
    attr_accessor :chunk_size, :chunk_overlap, :token_count_fn

    def initialize(chunk_size: 1024, chunk_overlap: 64, token_count_fn: nil)
      @chunk_size = chunk_size
      @chunk_overlap = chunk_overlap
      @token_count_fn = token_count_fn
      return unless @chunk_overlap >= @chunk_size

      @chunk_overlap = 0
    end

    def splitted(text)
      raise NotImplementedError, 'splitted method should be implemented in a subclass'
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

    def split_with_separator_preservation(text, separator)
      if separator.is_a?(Regexp)
        # For regexp separators, preserve the separator in the chunks
        parts = text.split(separator)
        matches = text.scan(separator)

        splits = []

        # First part (before any separator)
        splits << parts[0] if parts.length.positive? && !parts[0].empty?

        # Remaining parts with their separators
        matches.each_with_index do |match, i|
          part_index = i + 1
          next unless part_index < parts.length

          # Reconstruct the chunk with the separator (remove leading \n)
          chunk = match.gsub(/^\n/, '') + parts[part_index]
          splits << chunk unless chunk.empty?
        end

        splits
      elsif separator.empty?
        # For string separators, use standard split
        text.chars
      else
        text.split(separator)
      end
    end

    def merged(splits, separator)
      results = [] # Array of strings
      current_splits = [] # Array of strings
      total = 0

      splits.each do |split|
        split_token_count = token_count(split)

        if total + split_token_count >= chunk_size && current_splits.length.positive?
          results << joined(current_splits, separator)

          while total > chunk_overlap || (total + split_token_count >= chunk_size && total.positive?)
            total -= token_count(current_splits.first)
            current_splits.shift
          end
        end

        current_splits << split
        total += split_token_count
      end

      results << joined(current_splits, separator) unless current_splits.empty?

      results
    end
  end
end
