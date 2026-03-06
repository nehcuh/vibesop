# frozen_string_literal: true

module Vibe
  # Generic utilities shared across all Vibe modules.
  #
  # Host requirements:
  #   @repo_root [String] — absolute path to the workflow repository root
  #                          (used by display_path)
  module Utils
    # --- Deep structure helpers ---

    def deep_merge(base, extra)
      return deep_copy(extra) if base.nil?
      return deep_copy(base) if extra.nil?

      if base.is_a?(Hash) && extra.is_a?(Hash)
        merged = deep_copy(base)
        extra.each do |key, value|
          merged[key] = merged.key?(key) ? deep_merge(merged[key], value) : deep_copy(value)
        end
        merged
      elsif base.is_a?(Array) && extra.is_a?(Array)
        (base + extra).uniq
      else
        deep_copy(extra)
      end
    end

    def deep_copy(value)
      return value if value.nil? || value == true || value == false || value.is_a?(Numeric)
      JSON.parse(JSON.generate(value))
    end

    def blankish?(value)
      value.nil? || value.to_s.strip.empty?
    end

    # --- Path helpers ---

    # Returns a display-friendly path: relative to @repo_root when possible,
    # otherwise the absolute path.
    def display_path(path)
      absolute = File.expand_path(path)
      repo_prefix = @repo_root.end_with?("/") ? @repo_root : "#{@repo_root}/"
      return "." if absolute == @repo_root
      return absolute.delete_prefix(repo_prefix) if absolute.start_with?(repo_prefix)

      absolute
    end

    # --- I/O helpers ---

    def read_yaml(relative_path)
      read_yaml_abs(File.join(@repo_root, relative_path))
    end

    def read_yaml_abs(path)
      YAML.safe_load(File.read(path), aliases: true)
    end

    def read_json(path)
      JSON.parse(File.read(path))
    end

    def read_json_if_exists(path)
      return nil unless File.exist?(path)

      read_json(path)
    end

    def write_json(path, content)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(content) + "\n")
    end

    # --- Formatting helpers ---

    def format_backtick_list(items)
      values = Array(items).map(&:to_s).reject { |item| item.strip.empty? }
      return "`none`" if values.empty?

      values.map { |item| "`#{item}`" }.join(", ")
    end
  end
end
