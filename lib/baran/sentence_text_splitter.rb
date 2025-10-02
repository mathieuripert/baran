# frozen_string_literal: true

module Baran
  class SentenceTextSplitter < TextSplitter
    def initialize(chunk_size: 1024, chunk_overlap: 64, token_count_fn: nil)
      super(chunk_size: chunk_size, chunk_overlap: chunk_overlap, token_count_fn: token_count_fn)
    end

    def splitted(text)
      # Use a regex to split text based on the specified sentence-ending characters followed by whitespace
      text.scan(/[^.!?]+[.!?]+(?:\s+|\z)/).map(&:strip)
    end
  end
end
