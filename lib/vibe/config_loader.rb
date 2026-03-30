# frozen_string_literal: true

require 'yaml'
require_relative 'errors'

module Vibe
  # Centralized configuration loading with consistent error handling
  #
  # Usage patterns:
  #
  #   # As module function
  #   ConfigLoader.load_yaml('path/to/config.yaml')
  #   ConfigLoader.load_yaml('path/to/config.yaml', default: {})
  #
  #   # With symbolized keys
  #   ConfigLoader.load_yaml('path/to/config.yaml', symbolize_keys: true)
  #
  #   # Mixed into a class
  #   class MyClass
  #     include ConfigLoader
  #
  #     def load_config
  #       load_yaml('config.yaml', default: default_config)
  #     end
  #   end
  #
  module ConfigLoader
    # Load a YAML file with consistent error handling and optional defaults
    #
    # @param path [String] Path to YAML file
    # @param default [Object] Default value if file doesn't exist or is empty
    # @param symbolize_keys [Boolean] Convert hash keys to symbols
    # @param context [String] Context for error messages
    # @return [Hash, Array, Object] Parsed YAML content or default
    # @raise [ValidationError] If file exists but is invalid YAML
    def load_yaml(path, default: nil, symbolize_keys: false, context: nil)
      unless File.exist?(path)
        return default unless default.nil?
        raise ValidationError, "Config file not found: #{path}"
      end

      content = File.read(path)
      return default if content.strip.empty?

      parsed = YAML.safe_load(content, permitted_classes: [Symbol, Time, Date, DateTime, Regexp],
                                       aliases: true,
                                       filename: path)

      # Handle empty YAML files that parse to nil
      result = parsed || default

      # Symbolize keys if requested
      result = symbolize_keys_recursive(result) if symbolize_keys && result.is_a?(Hash)

      result
    rescue Psych::SyntaxError => e
      context_msg = context ? " (#{context})" : ''
      raise ValidationError, "Invalid YAML syntax in #{path}#{context_msg}: #{e.message}"
    rescue StandardError => e
      context_msg = context ? " loading #{context}" : ''
      raise ValidationError, "Failed to load #{path}#{context_msg}: #{e.message}"
    end

    # Load YAML or return default silently (no error if file missing)
    #
    # @param path [String] Path to YAML file
    # @param default [Object] Default value if file doesn't exist
    # @param symbolize_keys [Boolean] Convert hash keys to symbols
    # @return [Hash, Array, Object] Parsed YAML content or default
    def load_yaml_silent(path, default: {}, symbolize_keys: false)
      return default unless File.exist?(path)
      load_yaml(path, default: default, symbolize_keys: symbolize_keys)
    rescue StandardError
      default
    end

    # Save data to YAML file with atomic write
    #
    # @param path [String] Path to save file
    # @param data [Hash, Array] Data to serialize
    # @param context [String] Context for error messages
    def save_yaml(path, data, context: nil)
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

      # Atomic write: write to temp file, then rename
      temp_path = "#{path}.tmp"
      File.write(temp_path, YAML.dump(data))
      File.rename(temp_path, path)
    rescue StandardError => e
      context_msg = context ? " saving #{context}" : ''
      raise ValidationError, "Failed to save #{path}#{context_msg}: #{e.message}"
    ensure
      File.delete(temp_path) if temp_path && File.exist?(temp_path)
    end

    # Merge multiple YAML files (later files override earlier ones)
    #
    # @param paths [Array<String>] Array of file paths
    # @param symbolize_keys [Boolean] Convert hash keys to symbols
    # @return [Hash] Merged configuration
    def merge_yaml_files(paths, symbolize_keys: false)
      result = {}
      paths.each do |path|
        next unless File.exist?(path)
        config = load_yaml(path, default: {}, symbolize_keys: symbolize_keys)
        result = deep_merge_hashes(result, config)
      end
      result
    end

    private

    # Recursively symbolize hash keys
    #
    # @param obj [Object] Object to process
    # @return [Object] Object with symbolized keys (if hash)
    def symbolize_keys_recursive(obj)
      case obj
      when Hash
        obj.transform_keys { |k| k.is_a?(String) ? k.to_sym : k }
           .transform_values { |v| symbolize_keys_recursive(v) }
      when Array
        obj.map { |v| symbolize_keys_recursive(v) }
      else
        obj
      end
    end

    # Deep merge two hashes (recursive)
    #
    # @param base [Hash] Base hash
    # @param override [Hash] Override hash
    # @return [Hash] Merged hash
    def deep_merge_hashes(base, override)
      base.merge(override) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge_hashes(old_val, new_val)
        else
          new_val
        end
      end
    end

    # Make key methods available as module functions
    module_function :load_yaml, :load_yaml_silent, :save_yaml, :merge_yaml_files
  end
end
