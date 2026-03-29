# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'securerandom'
require 'time'
require 'shellwords'

module Vibe
  class ExperimentManager
    class ExperimentError < StandardError; end
    class ExperimentNotFoundError < ExperimentError; end

    attr_reader :config_path, :results_path, :beliefs_path, :worktree_path, :tag

    def initialize(config_path)
      @config_path = config_path
      @config = load_config
      @results_path = File.join(File.dirname(config_path), '.experiment', 'results.tsv')
      @beliefs_path = File.join(File.dirname(config_path), '.experiment', 'beliefs.md')
      @worktree_path = File.join(File.dirname(config_path), '.experiment', 'worktree')
      @tag = derive_tag
    end

    def config
      @config
    end

    def load_config
      raise ExperimentNotFoundError, "Config not found: #{@config_path}" unless File.exist?(@config_path)

      parsed = YAML.safe_load(File.read(@config_path))
      unless parsed.is_a?(Hash) && parsed['domain']
        raise ExperimentError,
              "experiment.yaml must have 'domain' key with 'objective' + 'scope' + 'evaluator' + 'constraints' fields"
      end

      parsed
    end

    def derive_tag
      domain = @config['domain'].to_s.downcase.gsub(/[^a-z0-9]+/, '-')
      "#{domain}-#{Time.now.strftime('%Y%m%d%H%M%S')}"
    end

    def start
      FileUtils.mkdir_p(File.dirname(@results_path))
      FileUtils.mkdir_p(File.dirname(@beliefs_path))

      headers = ['commit'] + rubric_ids + ['compound', 'status', 'description']
      File.write(@results_path, headers.join("\t") + "\n")

      File.write(@beliefs_path, generate_initial_beliefs)

      FileUtils.mkdir_p(@worktree_path)

      worktree_branch = "experiment/#{@tag}"
      out, status = Open3.capture2e("git worktree add #{@worktree_path} -b #{worktree_branch} 2>&1")
      unless status.success?
        FileUtils.rm_rf(@worktree_path)
        raise ExperimentError, "Failed to create worktree: #{out}"
      end

      { tag: @tag, config: @config, branch: worktree_branch }
    end

    def record_iteration(sha, scores, status, description)
      compound = calculate_compound(scores)
      row = [sha] + rubric_ids.map { |id| format('%.1f', scores[id].to_f) } +
            [format('%.1f', compound), status, description]
      File.open(@results_path, 'a') { |f| f.puts(row.join("\t") + "\n") }
    end

    def update_beliefs(content)
      File.write(@beliefs_path, content)
    end

    def read_beliefs
      File.exist?(@beliefs_path) ? File.read(@beliefs_path) : nil
    end

    def current_best
      return nil unless File.exist?(@results_path)

      lines = File.readlines(@results_path).drop(1).reject(&:strip.empty?)
      return nil if lines.empty?

      best_line = lines.max_by do |l|
        parts = l.strip.split("\t")
        parts[-3].to_f
      end

      return nil unless best_line

      parts = best_line.strip.split("\t")
      { commit: parts[0], score: parts[-3].to_f }
    end

    def count_iterations
      return 0 unless File.exist?(@results_path)

      File.readlines(@results_path).drop(1).reject(&:strip.empty?).size
    end

    def finish
      best = current_best
      total = count_iterations
      keeps = count_by_status('keep')
      discards = count_by_status('discard')

      {
        tag: @tag,
        branch: "experiment/#{@tag}",
        worktree: @worktree_path,
        best: best,
        total_iterations: total,
        keeps: keeps,
        discards: discards,
        summary: generate_summary(best, total, keeps, discards)
      }
    end

    def clean
      FileUtils.rm_rf(@worktree_path) if Dir.exist?(@worktree_path)
      FileUtils.rm_f(@results_path)
      FileUtils.rm_f(@beliefs_path)
      FileUtils.rm_rf(File.dirname(@results_path))
    end

    def rubric_ids
      rubric = @config.dig('objective', 'evaluator', 'rubric')
      return ['score'] unless rubric.is_a?(Array) && !rubric.empty?

      rubric.map { |r| r['id'] }
    end

    def calculate_compound(scores)
      rubric = @config.dig('objective', 'evaluator', 'rubric')
      return scores.values.first.to_f if !rubric.is_a?(Array) || rubric.empty?

      rubric.sum do |r|
        weight = r['weight'] || (1.0 / rubric.size)
        scores[r['id']].to_f * weight
      end
    end

    private

    require 'open3'

    def generate_initial_beliefs
      <<~BELIEFS
        ## Current Beliefs (max 20)
        (to be populated by Agent during experiment)

        ## Experiment History
        (to be populated by Agent during experiment)
      BELIEFS
    end

    def count_by_status(status)
      return 0 unless File.exist?(@results_path)

      File.readlines(@results_path).drop(1).count do |l|
        parts = l.strip.split("\t")
        parts[-2] == status
      end
    end

    def generate_summary(best, total, keeps, discards)
      lines = [
        "Experiment Summary for #{@tag}",
        "  Total iterations: #{total}",
        "  Keeps: #{keeps}, Discards: #{discards}",
        "  Best compound score: #{best ? best[:score] : 'N/A'}",
        "  Best commit: #{best ? best[:commit] : 'N/A'}",
        "  Branch: experiment/#{@tag}",
        "  Worktree: #{@worktree_path}"
      ]
      lines.join("\n")
    end
  end
end
