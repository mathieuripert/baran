# Baran

![v](https://badgen.net/rubygems/v/baran)
![dt](https://badgen.net/rubygems/dt/baran)
![license](https://badgen.net/github/license/kawakamimoeki/baran)

Text Splitter for Large Language Model datasets.

To avoid token constraints and improve the accuracy of vector search in the Large Language Model, it is necessary to divide the document. This gem supports splitting the text in the specified manner.

## Features

Baran provides efficient text splitting capabilities with the following key features:

- **Chunk Size Control**: Split text into specified sizes
- **Overlap Management**: Maintain continuity between chunks with configurable overlap
- **Context Preservation**: Respect semantic boundaries in text
- **Metadata Support**: Attach metadata to each chunk
- **Custom Token Counting**: Use word counting, LLM tokenizers, or any custom token counting method
- **Multiple Splitting Strategies**: Character-based, recursive, sentence-based, and Markdown-aware splitting

## Installation

### Using Bundler

Add this line to your application's Gemfile:

```ruby
gem 'baran'
```

And then execute:

    $ bundle install

### Direct Installation

    $ gem install baran

## Quick Start

```ruby
require 'baran'

# Basic text splitting
splitter = Baran::CharacterTextSplitter.new(chunk_size: 500, chunk_overlap: 50)
chunks = splitter.chunks("Your long text here...")

# Access chunk data
chunks.each do |chunk|
  puts "Text: #{chunk[:text]}"
  puts "Position: #{chunk[:cursor]}"
end
```

## Usage

### Default Parameters

- `chunk_size`: 1024 (characters)
- `chunk_overlap`: 64 (characters)

### Character Text Splitter

Splitting by the specified character.

```ruby
splitter = Baran::CharacterTextSplitter.new(
    chunk_size: 1024,
    chunk_overlap: 64,
    separator: "\n\n"
)
chunks = splitter.chunks(text, metadata: { source: "document.txt" })
# => [{ cursor: 0, text: "...", metadata: { source: "document.txt" } }, ...]
```

### Recursive Character Text Splitter

Splitting by the specified characters recursively, using the first separator found in the text.

```ruby
splitter = Baran::RecursiveCharacterTextSplitter.new(
    chunk_size: 1024,
    chunk_overlap: 64,
    separators: ["\n\n", "\n", " ", ""]
)
chunks = splitter.chunks(text, metadata: { type: "article" })
# => [{ cursor: 0, text: "...", metadata: { type: "article" } }, ...]
```

### Sentence Text Splitter

Splitting text by sentence boundaries (periods, exclamation marks, question marks).

```ruby
splitter = Baran::SentenceTextSplitter.new(
    chunk_size: 2000,
    chunk_overlap: 200
)
chunks = splitter.chunks(text)
# => [{ cursor: 0, text: "Complete sentence.", metadata: nil }, ...]
```

### Markdown Text Splitter

Splitting by Markdown structure with awareness of headers, code blocks, and other elements.

```ruby
splitter = Baran::MarkdownSplitter.new(
    chunk_size: 1500,
    chunk_overlap: 150
)
chunks = splitter.chunks(markdown_text, metadata: { format: "markdown" })
# => [{ cursor: 0, text: "# Header\n\nContent...", metadata: { format: "markdown" } }, ...]
```

Split with the following priority:

```ruby
[
    "\n# ",         # h1
    "\n## ",        # h2
    "\n### ",       # h3
    "\n#### ",      # h4
    "\n##### ",     # h5
    "\n###### ",    # h6
    "```\n\n",      # code block
    "\n\n***\n\n",  # horizontal rule
    "\n\n---\n\n",  # horizontal rule
    "\n\n___\n\n",  # horizontal rule
    "\n\n",         # paragraph break
    "\n",           # line break
    " ",            # space
    ""              # character
]
```

## Advanced Usage

### Working with Metadata

```ruby
splitter = Baran::RecursiveCharacterTextSplitter.new
document_text = File.read('document.txt')

chunks = splitter.chunks(
  document_text,
  metadata: {
    source: 'document.txt',
    created_at: Time.now,
    author: 'Author Name'
  }
)

chunks.each do |chunk|
  puts "Text: #{chunk[:text]}"
  puts "Position: #{chunk[:cursor]}"
  puts "Source: #{chunk[:metadata][:source]}"
end
```

### Processing Large Documents

```ruby
class DocumentProcessor
  def initialize
    @splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 1000,
      chunk_overlap: 100
    )
  end

  def process_file(file_path)
    content = File.read(file_path)
    
    chunks = @splitter.chunks(
      content,
      metadata: {
        file_path: file_path,
        file_size: File.size(file_path),
        processed_at: Time.now
      }
    )

    chunks.each_with_index do |chunk, index|
      save_to_vector_store(chunk, index)
    end
  end

  private

  def save_to_vector_store(chunk, index)
    # Your vector storage logic here
    puts "Saved chunk #{index}: #{chunk[:text].length} chars"
  end
end
```

### Comparing Splitting Strategies

```ruby
text = File.read('sample.md')

# Character-based splitting
char_splitter = Baran::CharacterTextSplitter.new(chunk_size: 500)
char_chunks = char_splitter.chunks(text)

# Recursive splitting
recursive_splitter = Baran::RecursiveCharacterTextSplitter.new(chunk_size: 500)
recursive_chunks = recursive_splitter.chunks(text)

# Markdown-aware splitting
md_splitter = Baran::MarkdownSplitter.new(chunk_size: 500)
md_chunks = md_splitter.chunks(text)

puts "Character-based: #{char_chunks.length} chunks"
puts "Recursive: #{recursive_chunks.length} chunks"
puts "Markdown-aware: #{md_chunks.length} chunks"
```

## Custom Token Counting

Baran supports custom token counting functions, allowing you to use different methods for measuring chunk sizes beyond simple character counting. This is particularly useful when working with LLM tokenizers or other token-based systems.

### Basic Token Counting

```ruby
# Word counting instead of character counting
word_counter = ->(text) { text.split(' ').length }
splitter = Baran::RecursiveCharacterTextSplitter.new(
  chunk_size: 100,        # 100 words instead of characters
  chunk_overlap: 10,      # 10 words overlap
  token_count_fn: word_counter
)

text = "This is a sample text that will be split based on word count."
chunks = splitter.chunks(text)

chunks.each do |chunk|
  word_count = chunk[:text].split(' ').length
  puts "Chunk: '#{chunk[:text]}' (#{word_count} words)"
end
```

### LLM Token Counting

#### Using tiktoken_ruby for OpenAI Models

For accurate token counting with OpenAI GPT models, use the [tiktoken_ruby](https://github.com/IAPark/tiktoken_ruby) gem:

```ruby
require 'tiktoken_ruby'

# Get the encoder for GPT-4
encoder = Tiktoken.encoding_for_model("gpt-4")

# Create a token counter function
token_counter = ->(text) { encoder.encode(text).length }

# Use with Baran splitters
splitter = Baran::RecursiveCharacterTextSplitter.new(
  chunk_size: 1000,       # 1000 tokens
  chunk_overlap: 100,     # 100 tokens overlap
  token_count_fn: token_counter
)

text = "Your long text that needs to be split into GPT-4 token-sized chunks..."
chunks = splitter.chunks(text)

chunks.each do |chunk|
  token_count = encoder.encode(chunk[:text]).length
  puts "Chunk: '#{chunk[:text]}' (#{token_count} tokens)"
end
```

#### Using Different OpenAI Models

```ruby
require 'tiktoken_ruby'

# For GPT-3.5-turbo
gpt35_encoder = Tiktoken.encoding_for_model("gpt-3.5-turbo")
gpt35_counter = ->(text) { gpt35_encoder.encode(text).length }

# For GPT-4o
gpt4o_encoder = Tiktoken.encoding_for_model("gpt-4o")
gpt4o_counter = ->(text) { gpt4o_encoder.encode(text).length }

# Use with different chunk sizes based on model context limits
gpt35_splitter = Baran::RecursiveCharacterTextSplitter.new(
  chunk_size: 2000,      # Smaller chunks for GPT-3.5
  chunk_overlap: 200,
  token_count_fn: gpt35_counter
)

gpt4o_splitter = Baran::RecursiveCharacterTextSplitter.new(
  chunk_size: 4000,      # Larger chunks for GPT-4o
  chunk_overlap: 400,
  token_count_fn: gpt4o_counter
)
```

#### Custom Token Counting (Fallback)

If you don't have access to tiktoken_ruby, you can use a simplified approximation:

```ruby
# Rough approximation for OpenAI models
def count_tokens(text)
  # This is a simplified example - use tiktoken_ruby for accuracy
  text.split(' ').length * 1.3  # Rough approximation
end

token_counter = ->(text) { count_tokens(text).to_i }
splitter = Baran::RecursiveCharacterTextSplitter.new(
  chunk_size: 1000,       # 1000 tokens
  chunk_overlap: 100,     # 100 tokens overlap
  token_count_fn: token_counter
)
```

### All Splitter Types Support Token Counting

```ruby
require 'tiktoken_ruby'

# Get encoder for accurate token counting
encoder = Tiktoken.encoding_for_model("gpt-4")
token_counter = ->(text) { encoder.encode(text).length }

# Character splitter with token counting
char_splitter = Baran::CharacterTextSplitter.new(
  chunk_size: 500,        # 500 tokens
  chunk_overlap: 50,      # 50 tokens overlap
  separator: ' ',
  token_count_fn: token_counter
)

# Sentence splitter with token counting
sentence_splitter = Baran::SentenceTextSplitter.new(
  chunk_size: 200,        # 200 tokens
  chunk_overlap: 20,      # 20 tokens overlap
  token_count_fn: token_counter
)

# Markdown splitter with token counting
markdown_splitter = Baran::MarkdownSplitter.new(
  chunk_size: 1000,       # 1000 tokens
  chunk_overlap: 100,     # 100 tokens overlap
  token_count_fn: token_counter
)

# Recursive splitter with token counting (most flexible)
recursive_splitter = Baran::RecursiveCharacterTextSplitter.new(
  chunk_size: 1500,       # 1500 tokens
  chunk_overlap: 150,     # 150 tokens overlap
  token_count_fn: token_counter
)
```

### Practical Example: Processing Documents for GPT-4

```ruby
require 'tiktoken_ruby'

class DocumentProcessor
  def initialize
    @encoder = Tiktoken.encoding_for_model("gpt-4")
    @token_counter = ->(text) { @encoder.encode(text).length }
    
    @splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: 2000,      # 2000 tokens per chunk
      chunk_overlap: 200,    # 200 tokens overlap
      token_count_fn: @token_counter
    )
  end

  def process_document(text, metadata = {})
    chunks = @splitter.chunks(text, metadata: metadata)
    
    chunks.each_with_index do |chunk, index|
      token_count = @token_counter.call(chunk[:text])
      puts "Chunk #{index + 1}: #{token_count} tokens"
      puts "Text: #{chunk[:text][0..100]}..."
      puts "---"
    end
    
    chunks
  end
end

# Usage
processor = DocumentProcessor.new
long_text = "Your very long document text here..."
chunks = processor.process_document(long_text, { source: "document.pdf" })
```

### Backward Compatibility

The token counting feature is fully backward compatible. If no `token_count_fn` is provided, the splitters default to character counting (the original behavior):

```ruby
# This works exactly as before (character counting)
splitter = Baran::RecursiveCharacterTextSplitter.new(chunk_size: 1024, chunk_overlap: 64)

# This also works (explicit character counting)
char_counter = ->(text) { text.length }
splitter = Baran::RecursiveCharacterTextSplitter.new(
  chunk_size: 1024,
  chunk_overlap: 64,
  token_count_fn: char_counter
)
```

### Advanced Token Counting Examples

```ruby
# Custom token counting for specific use cases
def custom_token_count(text)
  # Count words, but weight longer words more
  words = text.split(' ')
  words.sum { |word| word.length > 5 ? 2 : 1 }
end

custom_counter = ->(text) { custom_token_count(text) }
splitter = Baran::RecursiveCharacterTextSplitter.new(
  chunk_size: 50,
  chunk_overlap: 5,
  token_count_fn: custom_counter
)

# Token counting with preprocessing
def preprocessed_token_count(text)
  # Remove extra whitespace and count meaningful tokens
  cleaned = text.gsub(/\s+/, ' ').strip
  cleaned.split(' ').length
end

preprocessed_counter = ->(text) { preprocessed_token_count(text) }
splitter = Baran::RecursiveCharacterTextSplitter.new(
  chunk_size: 100,
  chunk_overlap: 10,
  token_count_fn: preprocessed_counter
)
```

## API Reference

### TextSplitter (Base Class)

Base class for all text splitters.

#### Methods

##### `initialize(chunk_size: 1024, chunk_overlap: 64, token_count_fn: nil)`

- `chunk_size` (Integer): Maximum characters/tokens per chunk
- `chunk_overlap` (Integer): Characters/tokens to overlap between chunks
- `token_count_fn` (Proc, optional): Custom function for counting tokens. If not provided, defaults to character counting

##### `chunks(text, metadata: nil)`

Returns an array of chunk hashes with `:text`, `:cursor`, and optional `:metadata` keys.

### CharacterTextSplitter

Splits text using a specified separator.

#### Additional Parameters

- `separator` (String): Character(s) to split on (default: "\n\n")

### RecursiveCharacterTextSplitter

Recursively splits text using multiple separators in priority order.

#### Additional Parameters

- `separators` (Array): Array of separators in priority order (default: ["\n\n", "\n", " "])

### SentenceTextSplitter

Splits text at sentence boundaries using regex pattern matching.

Detects sentences ending with `.`, `!`, or `?` followed by whitespace or end of string.

### MarkdownSplitter

Splits Markdown text while preserving document structure.

Inherits from `RecursiveCharacterTextSplitter` with Markdown-specific separators.

## Best Practices

### Choosing Chunk Size

```ruby
# For GPT-3.5 (4K context window)
small_splitter = Baran::RecursiveCharacterTextSplitter.new(chunk_size: 500)

# For GPT-4 (8K context window)
medium_splitter = Baran::RecursiveCharacterTextSplitter.new(chunk_size: 1000)

# For Claude-2 (100K context window)
large_splitter = Baran::RecursiveCharacterTextSplitter.new(chunk_size: 4000)
```

### Setting Overlap

```ruby
# General documents: 5-10% of chunk size
general_splitter = Baran::CharacterTextSplitter.new(
  chunk_size: 1000,
  chunk_overlap: 100  # 10%
)

# Technical documents: Higher overlap for better context
technical_splitter = Baran::RecursiveCharacterTextSplitter.new(
  chunk_size: 800,
  chunk_overlap: 150  # ~19%
)
```

### Choosing the Right Splitter

- **CharacterTextSplitter**: Simple documents with consistent structure
- **RecursiveCharacterTextSplitter**: General-purpose text splitting
- **SentenceTextSplitter**: When sentence integrity is important
- **MarkdownSplitter**: For Markdown documents and documentation

## Error Handling

```ruby
begin
  # This will raise an error
  invalid_splitter = Baran::TextSplitter.new(
    chunk_size: 100,
    chunk_overlap: 100  # overlap >= chunk_size
  )
rescue RuntimeError => e
  puts "Error: #{e.message}"
  # => "Cannot have chunk_overlap >= chunk_size"
end
```

## Performance Considerations

For large files, consider streaming processing:

```ruby
def process_large_file(file_path)
  splitter = Baran::RecursiveCharacterTextSplitter.new
  
  File.foreach(file_path, "\n\n") do |paragraph|
    chunks = splitter.chunks(paragraph)
    chunks.each { |chunk| yield chunk }
  end
end

process_large_file('huge_document.txt') do |chunk|
  # Process each chunk individually
  save_to_database(chunk)
end
```

## Version Information

- **Current Version**: 0.2.1
- **Ruby Requirement**: >= 2.6.0
- **License**: MIT

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To run tests:

```bash
bundle exec rake
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kawakamimoeki/baran. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/kawakamimoeki/baran/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Baran project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/kawakamimoeki/baran/blob/main/CODE_OF_CONDUCT.md).