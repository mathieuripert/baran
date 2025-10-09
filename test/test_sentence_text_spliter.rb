# frozen_string_literal: true

require 'minitest/autorun'
require 'baran'

class TestSentenceTextSplitter < Minitest::Test
  def setup
    @splitter = Baran::SentenceTextSplitter.new(chunk_size: 10, chunk_overlap: 5)
    @story = <<~TEXT
      Hack and jill
        went up the hill to fetch
        a pail of water.  Jack fell
      down and broke his crown and Jill
        came tumbling after.
      The pail went flying!  Was the water spilled?
        No, the water was splashed on Bo Peep.
    TEXT

    @expected = [
      'Hack and jill went up the hill to fetch a pail of water.',
      'Jack fell down and broke his crown and Jill came tumbling after.',
      'The pail went flying!',
      'Was the water spilled?',
      'No, the water was splashed on Bo Peep.'
    ]
  end

  def test_chunks
    chunks = @splitter.chunks(@story)
    sentences = format_chunks(chunks)
    assert_equal(sentences, @expected)
  end

  def test_chunks_without_trailing_whitespace
    chunks = @splitter.chunks(@story.strip)
    sentences = format_chunks(chunks)
    assert_equal(sentences, @expected)
  end

  private

  def format_chunks(chunks)
    chunks
      .map do |chunk|
      chunk[:text]
        .gsub(/\s+/, ' ')
        .strip
    end
  end
end
