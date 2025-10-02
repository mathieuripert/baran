require 'minitest/unit'
require 'baran'

MiniTest::Unit.autorun

class TestTextSplitter < MiniTest::Unit::TestCase
  def setup
    @splitter = Baran::TextSplitter.new
    @test_splitter = Class.new(Baran::TextSplitter) do
      def splitted(text)
        text.split(/ /)
      end
    end.new(chunk_size: 6, chunk_overlap: 2)
  end

  def test_initialize
    assert_equal 1024, @splitter.chunk_size
    assert_equal 64, @splitter.chunk_overlap

    splitter = Baran::TextSplitter.new(chunk_size: 1500, chunk_overlap: 300)
    assert_equal 1500, splitter.chunk_size
    assert_equal 300, splitter.chunk_overlap

    assert_raises RuntimeError, 'Cannot have chunk_overlap >= chunk_size' do
      Baran::TextSplitter.new(chunk_size: 1000, chunk_overlap: 1000)
    end
  end

  def test_splitted
    assert_raises NotImplementedError, 'splitted method should be implemented in a subclass' do
      @splitter.splitted('some text')
    end
  end

  def test_splitted_with_custom_text_splitter
    markdown_splitter = Baran::MarkdownSplitter.new(chunk_size: 10, chunk_overlap: 1)
    text = <<~TEXT
      ## Heading

      This is a sample text
      ---

      Another section"
    TEXT
    splitted = markdown_splitter.splitted(text)
    assert_equal ["## Heading", "This is a", "a sample", "text", "---", "Another", "section\""], splitted
  end

  def test_chunks
    text = 'text one'
    metadata = {}
    documents = @test_splitter.chunks(text)

    assert_equal 2, documents.size
    assert_equal 'text', documents[0][:text]
    assert_equal 4, documents[1][:cursor]
  end

  def test_chunks_with_metadata
    text = 'text one'
    metadata = { page: 1 }
    documents = @test_splitter.chunks(text, metadata: metadata)

    assert_equal({ page: 1 }, documents[0][:metadata])
  end

  def test_joined
    items = ['one', 'two', 'three']
    separator = ' '
    joined_text = @test_splitter.joined(items, separator)

    assert_equal 'one two three', joined_text
  end

  def test_merged
    [
      { splits: ['txt', 'i', 'txt', 'o'], expected: ['txt i', 'i txt o'] },
      { splits: ['txt', 'ii', 'txt', 'o'], expected: ['txt ii', 'ii txt', 'o'] },
      { splits: ['txt', 'ii', 'tx', 'oo'], expected: ['txt ii', 'ii tx', 'tx oo'] },
    ].each do |data|
      assert_equal data[:expected], @test_splitter.merged(data[:splits], ' ')
    end
  end

  def test_token_count_default
    # Test default character counting
    assert_equal 5, @splitter.token_count("hello")
    assert_equal 0, @splitter.token_count("")
  end

  def test_token_count_custom
    # Test custom word counting function
    word_counter = ->(text) { text.split(' ').length }
    splitter = Baran::TextSplitter.new(token_count_fn: word_counter)
    
    assert_equal 1, splitter.token_count("hello")
    assert_equal 3, splitter.token_count("hello world test")
    assert_equal 0, splitter.token_count("")
  end

  def test_recursive_splitter_with_custom_token_count
    # Test RecursiveCharacterTextSplitter with word counting
    word_counter = ->(text) { text.split(' ').length }
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 3, 
      chunk_overlap: 1, 
      token_count_fn: word_counter
    )
    
    text = "This is a test sentence with multiple words"
    chunks = splitter.chunks(text)
    
    # Verify that chunks are created based on word count, not character count
    chunks.each do |chunk|
      word_count = chunk[:text].split(' ').length
      assert word_count <= 3, "Chunk has #{word_count} words, should be <= 3"
    end
  end

  def test_character_splitter_with_custom_token_count
    # Test CharacterTextSplitter with word counting
    word_counter = ->(text) { text.split(' ').length }
    splitter = Baran::CharacterTextSplitter.new(
      chunk_size: 2, 
      chunk_overlap: 1, 
      separator: ' ',  # Use space as separator to split by words
      token_count_fn: word_counter
    )
    
    text = "First sentence. Second sentence. Third sentence."
    chunks = splitter.chunks(text)
    
    # Verify that chunks are created based on word count
    chunks.each do |chunk|
      word_count = chunk[:text].split(' ').length
      assert word_count <= 2, "Chunk has #{word_count} words, should be <= 2"
    end
  end

  def test_markdown_splitter_with_custom_token_count
    # Test MarkdownSplitter with word counting
    word_counter = ->(text) { text.split(' ').length }
    splitter = Baran::MarkdownSplitter.new(
      chunk_size: 4, 
      chunk_overlap: 1, 
      token_count_fn: word_counter
    )
    
    text = <<~TEXT
      # Heading One
      
      This is the first paragraph with multiple words.
      
      ## Heading Two
      
      This is the second paragraph with more words.
    TEXT
    
    chunks = splitter.chunks(text)
    
    # Verify that chunks are created based on word count
    chunks.each do |chunk|
      word_count = chunk[:text].split(' ').length
      assert word_count <= 4, "Chunk has #{word_count} words, should be <= 4"
    end
  end
end
