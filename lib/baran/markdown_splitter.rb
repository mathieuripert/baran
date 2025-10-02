require_relative './recursive_character_text_splitter'

module Baran
  class MarkdownSplitter < RecursiveCharacterTextSplitter
    def initialize(chunk_size: 1024, chunk_overlap: 64, token_count_fn: nil)
      separators = [
        /\n# /, # h1
        /\n## /, # h2
        /\n### /, # h3
        /\n#### /, # h4
        /\n##### /, # h5
        /\n###### /, # h6
        /```\n\n/, # code block
        /\n\n\*{3,}\n\n/, # horizontal rule (***)
        /\n\n-{3,}\n\n/, # horizontal rule (---)
        /\n\n_{3,}\n\n/, # horizontal rule (___)
        "\n\n", # paragraph break
      ]
      super(chunk_size: chunk_size, chunk_overlap: chunk_overlap, separators: separators, token_count_fn: token_count_fn)
    end
  end
end