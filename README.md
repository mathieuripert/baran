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

## API Reference

### TextSplitter (Base Class)

Base class for all text splitters.

#### Methods

##### `initialize(chunk_size: 1024, chunk_overlap: 64)`

- `chunk_size` (Integer): Maximum characters per chunk
- `chunk_overlap` (Integer): Characters to overlap between chunks

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