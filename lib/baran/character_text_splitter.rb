require_relative './text_splitter'

module Baran
  class CharacterTextSplitter < TextSplitter
    attr_accessor :separator

    def initialize(chunk_size: 1024, chunk_overlap: 64, separator: nil, token_count_fn: nil)
      super(chunk_size: chunk_size, chunk_overlap: chunk_overlap, token_count_fn: token_count_fn)
      @separator = separator || "\n\n"
    end

    def splitted(text)
      splits = split_with_separator_preservation(text, @separator)
      merged(splits, @separator)
    end
  end
end
