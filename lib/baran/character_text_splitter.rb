require_relative './text_splitter'

module Baran
  class CharacterTextSplitter < TextSplitter
    attr_accessor :separator

    def initialize(chunk_size: 1024, chunk_overlap: 64, separator: nil)
      super(chunk_size: chunk_size, chunk_overlap: chunk_overlap)
      @separator = separator || "\n\n"
    end

    def splitted(text)
      if separator.is_a?(Regexp)
        # For regexp separators, split the text and reconstruct with separators
        parts = text.split(separator)
        separators = text.scan(separator)
        
        # Reconstruct the chunks with separators
        splits = []
        
        # Handle the first part (before any separator)
        if parts.length > 0 && !parts[0].empty?
          splits << parts[0]
        end
        
        # For each separator, combine it with the following part
        separators.each_with_index do |sep, i|
          part_index = i + 1
          if part_index < parts.length
            chunk = sep + parts[part_index]
            splits << chunk unless chunk.empty?
          end
        end
      elsif separator.empty?
        splits = text.chars
      else
        splits = text.split(separator)
      end
      merged(splits, @separator)
    end
  end
end
