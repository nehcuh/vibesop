# frozen_string_literal: true

require 'set'
require_relative 'defaults'

module Vibe
  # Advanced semantic matching for skill routing
  # Uses TF-IDF inspired scoring and context awareness
  module SemanticMatcher
    STOP_WORDS = Set.new(%w[
      a an the and or but in on at to for of with by
      的 了 在 是 我 有 和 就 不 人 都 一 一个 上 也 很 到 说 要 去 你 会 着 没有 看 好 自己 这 那 这些 那些 这个 那个
    ]).freeze

    # Calculate cosine similarity between two texts
    # @param text1 [String]
    # @param text2 [String]
    # @return [Float] similarity score 0.0-1.0
    def cosine_similarity(text1, text2)
      vec1 = text_to_vector(text1)
      vec2 = text_to_vector(text2)

      return 0.0 if vec1.empty? || vec2.empty?

      dot_product = vec1.sum { |word, count| count * vec2[word].to_i }
      magnitude1 = Math.sqrt(vec1.sum { |_, count| count**2 })
      magnitude2 = Math.sqrt(vec2.sum { |_, count| count**2 })

      return 0.0 if magnitude1.zero? || magnitude2.zero?

      dot_product / (magnitude1 * magnitude2)
    end

    # Calculate TF-IDF weighted similarity
    # @param text [String] user input
    # @param documents [Array<String>] skill intents/descriptions
    # @param idf_scores [Hash] pre-calculated IDF scores
    # @return [Array<Hash>] [{document: str, score: float}, ...]
    def tfidf_similarity(text, documents, idf_scores = {})
      text_vec = tfidf_vector(text, documents + [text], idf_scores)

      documents.map do |doc|
        doc_vec = tfidf_vector(doc, documents + [text], idf_scores)
        score = vector_cosine_similarity(text_vec, doc_vec)
        { document: doc, score: score }
      end.sort_by { |r| -r[:score] }
    end

    # Match with fuzzy support (handles typos and variations)
    # @param input [String]
    # @param candidates [Array<String>]
    # @return [Array<Hash>] matches with scores
    def fuzzy_match(input, candidates)
      input_downcase = input.downcase
      input_words = tokenize(input_downcase)

      candidates.map do |candidate|
        candidate_downcase = candidate.downcase

        # Exact match
        if candidate_downcase.include?(input_downcase) ||
           input_downcase.include?(candidate_downcase)
          return [{ candidate: candidate, score: 1.0, match_type: :exact }]
        end

        # Word-level similarity
        candidate_words = tokenize(candidate_downcase)
        score = word_overlap_score(input_words, candidate_words)

        # Character-level similarity for typos
        if score < Defaults::SEMANTIC_MIN_SCORE
          char_score = character_similarity(input_downcase, candidate_downcase)
          score = [score, char_score * 0.7].max
        end

        { candidate: candidate, score: score, match_type: :fuzzy }
      end.sort_by { |r| -r[:score] }
    end

    private

    def tokenize(text)
      # Normalize: lowercase, remove punctuation, split
      normalized = text.downcase.gsub(/[^\w\s\u4e00-\u9fa5]/, ' ')
      words = normalized.split
      words.reject { |w| STOP_WORDS.include?(w) || w.length < 2 }
    end

    def text_to_vector(text)
      words = tokenize(text)
      vector = Hash.new(0)
      words.each { |w| vector[w] += 1 }
      vector
    end

    def tfidf_vector(text, all_documents, idf_scores)
      words = tokenize(text)
      term_freq = Hash.new(0)
      words.each { |w| term_freq[w] += 1 }

      # Normalize term frequency
      total_terms = words.length.to_f
      tf = term_freq.transform_values { |count| count / total_terms }

      # Apply IDF weighting
      tf.transform_values do |tf_val|
        word = tf.key(tf_val) || tf.find { |_, v| v == tf_val }&.first
        idf = idf_scores[word] || calculate_idf(word, all_documents)
        tf_val * idf
      end
    end

    def calculate_idf(word, documents)
      doc_count = documents.count { |doc| tokenize(doc).include?(word) }
      total_docs = documents.length.to_f
      Math.log((total_docs + 1) / (doc_count + 1)) + 1
    end

    def vector_cosine_similarity(vec1, vec2)
      all_keys = (vec1.keys + vec2.keys).uniq

      dot_product = all_keys.sum { |k| vec1[k].to_f * vec2[k].to_f }
      magnitude1 = Math.sqrt(vec1.values.sum { |v| v**2 })
      magnitude2 = Math.sqrt(vec2.values.sum { |v| v**2 })

      return 0.0 if magnitude1.zero? || magnitude2.zero?

      dot_product / (magnitude1 * magnitude2)
    end

    def word_overlap_score(words1, words2)
      return 0.0 if words1.empty? || words2.empty?

      intersection = (words1 & words2).size
      union = (words1 | words2).size

      # Jaccard similarity
      jaccard = intersection.to_f / union

      # Weighted by frequency
      intersection_weighted = words1.sum { |w| words2.include?(w) ? 1 : 0 }
      overlap_score = intersection_weighted.to_f / [words1.size, words2.size].max

      (jaccard + overlap_score) / 2
    end

    # Levenshtein-inspired character similarity
    def character_similarity(s1, s2)
      return 1.0 if s1 == s2
      return 0.0 if s1.empty? || s2.empty?

      # Simple n-gram similarity
      n = 2
      ngrams1 = s1.chars.each_cons(n).to_a
      ngrams2 = s2.chars.each_cons(n).to_a

      intersection = (ngrams1 & ngrams2).size
      union = (ngrams1 | ngrams2).size

      intersection.to_f / union
    end
  end
end
