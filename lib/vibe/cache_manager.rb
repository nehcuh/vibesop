# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'digest'
require 'time'

module Vibe
  # Multi-level cache manager for AI Triage results
  #
  # Architecture:
  #   Level 1: Memory cache (current session) - fastest, smallest
  #   Level 2: File cache (persistent) - slower, larger
  #   Level 3: Redis cache (optional) - distributed, scalable
  #
  # Features:
  #   - Automatic promotion/demotion between levels
  #   - TTL-based expiration
  #   - Cache statistics tracking
  #   - Thread-safe operations
  #   - Graceful degradation (if Redis fails, use file cache)
  #
  # Usage:
  #   cache = CacheManager.new
  #   cache.set('key', {value: 'data'}, ttl: 86400)
  #   result = cache.get('key')
  #   stats = cache.stats
  #
  class CacheManager
    CACHE_DIR = File.expand_path('~/.vibe/cache/ai_triage')
    MAX_MEMORY_CACHE_SIZE = 1000 # Max entries in memory cache
    DEFAULT_TTL = 86400 # 24 hours

    attr_reader :cache_dir, :memory_cache_max_size

    def initialize(cache_dir: CACHE_DIR, memory_cache_max_size: MAX_MEMORY_CACHE_SIZE)
      @cache_dir = cache_dir
      @memory_cache_max_size = memory_cache_max_size

      # Initialize memory cache (L1)
      @memory_cache = {}
      @memory_cache_access = {}
      @memory_cache_mutex = Mutex.new

      # Initialize statistics
      @stats = {
        l1_hits: 0,
        l1_misses: 0,
        l2_hits: 0,
        l2_misses: 0,
        l3_hits: 0,
        l3_misses: 0,
        sets: 0,
        deletes: 0
      }

      # Ensure cache directory exists
      ensure_cache_dir

      # Initialize Redis (L3) if available
      @redis_client = init_redis_client if ENV['REDIS_URL']
    end

    # Get cached value
    # @param key [String] Cache key
    # @return [Object, nil] Cached value or nil if not found/expired
    def get(key)
      # Level 1: Memory cache (fastest)
      if memory_cache_hit?(key)
        record_hit(:l1)
        value = @memory_cache[key][:value]

        # Update access time for LRU eviction
        update_memory_cache_access(key)

        return value
      end

      record_miss(:l1)

      # Level 2: File cache
      if file_cache_hit?(key)
        record_hit(:l2)
        data = read_file_cache(key)

        # Promote to L1 memory cache
        promote_to_memory_cache(key, data)

        return data[:value]
      end

      record_miss(:l2)

      # Level 3: Redis cache (optional)
      if @redis_client && redis_cache_hit?(key)
        record_hit(:l3)
        data = read_redis_cache(key)

        # Promote to L1 and L2
        promote_to_memory_cache(key, data)
        write_file_cache(key, data)

        return data[:value]
      end

      record_miss(:l3)

      nil
    end

    # Set cached value
    # @param key [String] Cache key
    # @param value [Object] Value to cache (must be JSON-serializable)
    # @param ttl [Integer] Time to live in seconds (default: 24 hours)
    def set(key, value, ttl: DEFAULT_TTL)
      raise ArgumentError, 'Key cannot be empty' if key.nil? || key.empty?
      raise ArgumentError, 'TTL must be positive' if ttl && ttl <= 0

      created_at = Time.now
      expires_at = created_at + ttl

      cache_data = {
        key: key,
        value: value,
        created_at: created_at.to_s,
        expires_at: expires_at.to_s,
        hits: 0
      }

      # Set in all levels
      set_memory_cache(key, cache_data)
      write_file_cache(key, cache_data)
      write_redis_cache(key, cache_data) if @redis_client

      @stats[:sets] += 1

      value
    rescue StandardError => e
      warn("Cache set error: #{e.message}")
      nil
    end

    # Check if key exists and is not expired
    # @param key [String] Cache key
    # @return [Boolean] True if key exists and is valid
    def exist?(key)
      get(key) != nil
    end

    # Delete cached value
    # @param key [String] Cache key
    # @return [Boolean] True if deleted, false if not found
    def delete(key)
      deleted = false

      # Delete from all levels
      @memory_cache_mutex.synchronize do
        deleted = true if @memory_cache.delete(key)
      end

      file_path = file_cache_path(key)
      if File.exist?(file_path)
        File.delete(file_path)
        deleted = true
      end

      if @redis_client
        begin
          deleted = true if @redis_client.del(key) > 0
        rescue Redis::BaseError => e
          warn("Redis delete error: #{e.message}")
        end
      end

      @stats[:deletes] += 1 if deleted

      deleted
    end

    # Clear cache
    # @param pattern [String, nil] Optional pattern to match keys
    def clear(pattern = nil)
      if pattern
        # Clear keys matching pattern
        clear_by_pattern(pattern)
      else
        # Clear all cache
        clear_all
      end
    end

    # Get cache statistics
    # @return [Hash] Statistics about cache usage
    def stats
      total_requests = @stats.values.sum
      total_hits = @stats[:l1_hits] + @stats[:l2_hits] + @stats[:l3_hits]
      total_misses = @stats[:l1_misses] + @stats[:l2_misses] + @stats[:l3_misses]

      total_entries = 0
      total_size = 0

      # Count L1 entries
      total_entries += @memory_cache.size

      # Count L2 entries
      if Dir.exist?(@cache_dir)
        Dir.glob(File.join(@cache_dir, '*.json')).each do |file|
          total_entries += 1
          total_size += File.size(file)
        end
      end

      {
        # Performance metrics
        total_requests: total_requests,
        total_hits: total_hits,
        total_misses: total_misses,
        hit_rate: total_requests > 0 ? (total_hits.to_f / total_requests).round(4) : 0,

        # Level breakdown
        l1: {
          size: @memory_cache.size,
          hits: @stats[:l1_hits],
          misses: @stats[:l1_misses],
          hit_rate: calculate_level_hit_rate(:l1)
        },
        l2: {
          size: count_l2_entries,
          hits: @stats[:l2_hits],
          misses: @stats[:l2_misses],
          hit_rate: calculate_level_hit_rate(:l2)
        },
        l3: {
          enabled: !@redis_client.nil?,
          hits: @stats[:l3_hits],
          misses: @stats[:l3_misses],
          hit_rate: calculate_level_hit_rate(:l3)
        },

        # Storage metrics
        total_entries: total_entries,
        total_size_bytes: total_size,
        total_size_mb: (total_size.to_f / 1024 / 1024).round(2),

        # Operations
        sets: @stats[:sets],
        deletes: @stats[:deletes]
      }
    end

    # Clean expired entries from all cache levels
    # @return [Integer] Number of entries cleaned
    def clean_expired
      cleaned = 0

      # Clean L1 (memory cache)
      @memory_cache_mutex.synchronize do
        @memory_cache.delete_if do |key, data|
          if expired?(data)
            cleaned += 1
            true
          else
            false
          end
        end
      end

      # Clean L2 (file cache)
      if Dir.exist?(@cache_dir)
        Dir.glob(File.join(@cache_dir, '*.json')).each do |file|
          begin
            data = JSON.parse(File.read(file))
            if expired?(data)
              File.delete(file)
              cleaned += 1
            end
          rescue JSON::ParserError, Errno::ENOENT
            # Skip corrupted files
            next
          end
        end
      end

      # L3 (Redis) - Let Redis handle TTL automatically

      cleaned
    end

    private

    # Memory cache (L1) methods

    def memory_cache_hit?(key)
      @memory_cache_mutex.synchronize do
        entry = @memory_cache[key]
        return false unless entry

        # Check expiration
        return false if expired?(entry)

        true
      end
    end

    def set_memory_cache(key, data)
      @memory_cache_mutex.synchronize do
        # Evict oldest entry if cache is full
        if @memory_cache.size >= @memory_cache_max_size
          evict_from_memory_cache
        end

        @memory_cache[key] = data
        @memory_cache_access[key] = Time.now.to_i
      end
    end

    def update_memory_cache_access(key)
      @memory_cache_mutex.synchronize do
        @memory_cache_access[key] = Time.now.to_i
      end
    end

    def promote_to_memory_cache(key, data)
      @memory_cache_mutex.synchronize do
        # Evict oldest entry if cache is full
        if @memory_cache.size >= @memory_cache_max_size
          evict_from_memory_cache
        end

        @memory_cache[key] = data
        @memory_cache_access[key] = Time.now.to_i
      end
    end

    def evict_from_memory_cache
      # Find least recently used entry
      lru_key = @memory_cache_access.min_by { |_, time| time }
      return if lru_key.nil?

      @memory_cache.delete(lru_key.first)
      @memory_cache_access.delete(lru_key.first)
    end

    # File cache (L2) methods

    def file_cache_hit?(key)
      file_path = file_cache_path(key)
      return false unless File.exist?(file_path)

      begin
        data = JSON.parse(File.read(file_path))
        return false if expired?(data)

        true
      rescue JSON::ParserError, Errno::ENOENT
        false
      end
    end

    def read_file_cache(key)
      file_path = file_cache_path(key)
      return nil unless File.exist?(file_path)

      data = JSON.parse(File.read(file_path))

      # Update hit count
      data['hits'] ||= 0
      data['hits'] += 1
      File.write(file_path, JSON.generate(data))

      data
    rescue JSON::ParserError, Errno::ENOENT => e
      warn("File cache read error: #{e.message}")
      nil
    end

    def write_file_cache(key, data)
      ensure_cache_dir
      file_path = file_cache_path(key)
      File.write(file_path, JSON.generate(data))
    end

    def file_cache_path(key)
      # Use SHA256 hash for filename
      hashed_key = Digest::SHA256.hexdigest(key)
      File.join(@cache_dir, "#{hashed_key}.json")
    end

    # Redis cache (L3) methods

    def init_redis_client
      return nil unless ENV['REDIS_URL']

      begin
        require 'redis'
        Redis.new(url: ENV['REDIS_URL'])
      rescue LoadError
        warn("Redis gem not installed, Redis caching disabled")
        nil
      rescue Redis::BaseError => e
        warn("Redis connection failed: #{e.message}")
        nil
      end
    end

    def redis_cache_hit?(key)
      return false unless @redis_client

      begin
        @redis_client.exists(key) > 0
      rescue Redis::BaseError => e
        warn("Redis EXISTS error: #{e.message}")
        false
      end
    end

    def read_redis_cache(key)
      begin
        data_json = @redis_client.get(key)
        return nil unless data_json

        JSON.parse(data_json)
      rescue Redis::BaseError, JSON::ParserError => e
        warn("Redis GET error: #{e.message}")
        nil
      end
    end

    def write_redis_cache(key, data)
      return unless @redis_client

      begin
        # Set with TTL
        ttl = calculate_ttl(data)
        @redis_client.setex(key, ttl, JSON.generate(data))
      rescue Redis::BaseError => e
        warn("Redis SET error: #{e.message}")
      end
    end

    # Utility methods

    def ensure_cache_dir
      FileUtils.mkdir_p(@cache_dir) unless Dir.exist?(@cache_dir)
    end

    def expired?(data)
      return false unless data['expires_at']

      expires_at = Time.parse(data['expires_at'])
      Time.now > expires_at
    rescue ArgumentError
      false
    end

    def calculate_ttl(data)
      return DEFAULT_TTL unless data['expires_at']

      expires_at = Time.parse(data['expires_at'])
      created_at = Time.parse(data['created_at'])

      (expires_at - created_at).to_i
    rescue ArgumentError
      DEFAULT_TTL
    end

    def record_hit(level)
      @stats[:"#{level}_hits"] += 1
    end

    def record_miss(level)
      @stats[:"#{level}_misses"] += 1
    end

    def calculate_level_hit_rate(level)
      hits = @stats[:"#{level}_hits"]
      misses = @stats[:"#{level}_misses"]
      total = hits + misses

      return 0.0 if total.zero?
      (hits.to_f / total).round(4)
    end

    def count_l2_entries
      return 0 unless Dir.exist?(@cache_dir)

      Dir.glob(File.join(@cache_dir, '*.json')).size
    end

    def clear_all
      # Clear L1
      @memory_cache_mutex.synchronize do
        @memory_cache.clear
        @memory_cache_access.clear
      end

      # Clear L2
      FileUtils.rm_rf(@cache_dir)
      ensure_cache_dir

      # Clear L3
      if @redis_client
        begin
          # Only delete keys with our prefix (if we use one)
          # For now, just flush all (be careful!)
          # @redis_client.flushdb
        rescue Redis::BaseError => e
          warn("Redis flush error: #{e.message}")
        end
      end

      # Reset stats
      @stats.each { |k, _| @stats[k] = 0 }
    end

    def clear_by_pattern(pattern)
      # This is a simplified implementation
      # For production, you'd want a more sophisticated pattern matching
      keys_to_delete = @memory_cache.keys.select { |k| k.include?(pattern) }

      keys_to_delete.each do |key|
        delete(key)
      end

      # For file cache and Redis, pattern matching would be more complex
      # This is left as an exercise for the reader
    end
  end
end
