# Integration Tests for Markdown Splitter

This directory contains a generic integration testing system for the Markdown Splitter that automatically discovers and tests any markdown files in the `test/data/` directory.

## How It Works

### File Naming Convention

The system uses a simple naming convention:
- **Input files**: `<filename>.md` - Markdown files to be processed
- **Output files**: `<filename>_output.json` - Expected chunk output for comparison

### Automatic Test Generation

For each `.md` file found in `test/data/`, the system automatically generates 5 test methods:

1. `test_<filename>_document_processing` - Verifies basic document processing
2. `test_<filename>_table_protection` - Ensures markdown tables aren't split
3. `test_<filename>_consistency` - Compares output against saved expected results
4. `test_<filename>_header_preservation` - Verifies headers are preserved correctly
5. `test_<filename>_chunk_size_limits` - Checks chunk size limits are respected

### First Run Behavior

When you add a new `.md` file:
1. The consistency test will automatically generate the corresponding `_output.json` file
2. The test will pass after generating the baseline
3. Subsequent runs will compare against this baseline

## Usage

### Adding New Test Cases

1. Create a new markdown file in `test/data/`:
   ```bash
   # Example: test/data/my_document.md
   ```

2. Run the tests:
   ```bash
   rake test
   ```

3. The system will automatically:
   - Discover your new file
   - Generate `test/data/my_document_output.json`
   - Run all 5 test types on your document

### Regenerating Output Files

If you need to update the expected output (e.g., after fixing a bug):

```bash
ruby test/regenerate_output_files.rb
```

This will regenerate all `*_output.json` files based on current splitter behavior.

### Current Test Files

- `input_text.md` - Complex annual report with tables and headers
- `simple_test.md` - Simple document with basic table

## Test Configuration

Default settings for all tests:
- **Chunk Size**: 400 characters
- **Chunk Overlap**: 50 characters
- **Splitter**: `Baran::MarkdownSplitter`

To modify these settings, edit the `discover_test_files` method in `test_markdown_splitter_integration.rb`.

## Running Tests

```bash
# Run all tests including integration tests
rake test

# Run only integration tests
ruby -Ilib test/test_markdown_splitter_integration.rb
```

## What Gets Tested

### Document Processing
- Chunks are generated
- Each chunk has required structure (text, cursor, length)
- Non-empty chunks

### Table Protection
- Markdown tables are detected
- Table rows are not split across chunks
- Tables remain intact even if they exceed chunk size

### Consistency
- Output matches previously saved results
- Chunk count, text, and metadata are identical
- Regression detection

### Header Preservation
- All markdown headers are preserved
- Headers appear in at least one chunk

### Chunk Size Limits
- Most chunks respect size limits
- Oversized chunks contain protected content (tables, unbreakable text)
