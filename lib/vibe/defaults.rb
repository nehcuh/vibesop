# frozen_string_literal: true

module Vibe
  # Centralized default constants used across modules.
  # Individual modules may override these via constructor config.
  module Defaults
    # --- Confidence thresholds ---
    CONFIDENCE_HIGH   = 0.8
    CONFIDENCE_MEDIUM = 0.6
    CONFIDENCE_LOW    = 0.4

    # --- Semantic matching ---
    SEMANTIC_MIN_SCORE = 0.5

    # --- Pattern analysis ---
    MIN_OCCURRENCES       = 3
    MIN_SUCCESS_RATE      = 0.7
    MIN_SEQUENCE_LENGTH   = 3
    SCAN_RECENT_SESSIONS  = 20

    # --- Memory trigger ---
    TRIGGER_MIN_OCCURRENCES   = 2
    TRIGGER_MAX_ENTRIES       = 100
    TRIGGER_MAX_CACHE_AGE_DAYS = 30

    # --- Network / IO ---
    CLONE_TIMEOUT = 60  # seconds

    # --- Instinct confidence labels ---
    def self.confidence_label(value)
      if value >= CONFIDENCE_HIGH
        'High'
      elsif value >= CONFIDENCE_MEDIUM
        'Medium'
      else
        'Low'
      end
    end
  end
end
