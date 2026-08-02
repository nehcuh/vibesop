# frozen_string_literal: true

require 'yaml'
require 'time'
require 'fileutils'
require 'tempfile'

module Vibe
  # Manages skill-craft triggers
  class TriggerManager
    attr_reader :config, :state_file, :state

    def initialize(config = {})
      @config = default_config.merge(config)
      @state_file = @config.delete('state_file') || state_path
      @state = load_state
    end

    def default_config
      {
        'triggers' => {
          'accumulation_threshold' => 10,
          'periodic_interval' => 7,
          'periodic_day' => 5, # Friday
          'project_completion' => true,
          'max_prompts_per_day' => 2,
          'quiet_hours_start' => 22,
          'quiet_hours_end' => 8
        }
      }
    end

    def state_path
      File.expand_path('~/.claude/.skill-craft-state.yaml')
    end

    def load_state
      unless File.exist?(@state_file)
        return { 'version' => '1.0', 'last_review' => nil,
                 'session_count' => 0 }
      end

      YAML.safe_load(File.read(@state_file))
    rescue StandardError
      { 'version' => '1.0', 'last_review' => nil, 'session_count' => 0 }
    end

    def save_state
      FileUtils.mkdir_p(File.dirname(@state_file))
      tmp = "#{@state_file}.tmp.#{Process.pid}"
      File.write(tmp, YAML.dump(@state))
      FileUtils.mv(tmp, @state_file)
    end

    # Check if any trigger should fire
    def check_triggers(context = {})
      triggers = []

      # Accumulation trigger
      if accumulation_trigger?(context)
        triggers << { type: :accumulation, message: accumulation_message }
      end

      # Periodic trigger
      triggers << { type: :periodic, message: periodic_message } if periodic_trigger?

      # Project completion trigger
      if project_completion_trigger?(context)
        triggers << { type: :project_completion, message: project_completion_message }
      end

      triggers
    end

    # Accumulation trigger: N sessions since last review
    def accumulation_trigger?(_context)
      session_count = @state['session_count'] || 0
      threshold = @config.dig('triggers', 'accumulation_threshold')

      session_count >= threshold
    end

    # Periodic trigger: Check if it's time for periodic review
    def periodic_trigger?
      return false unless @state['last_review']

      last_review = Time.parse(@state['last_review'])
      interval_days = @config.dig('triggers', 'periodic_interval')
      today = Date.today

      # Check if enough time has passed since last review
      return false if (today - last_review.to_date) < interval_days

      # Check day of week
      periodic_day = @config.dig('triggers', 'periodic_day')
      return false unless today.wday == periodic_day

      # Check if already prompted today
      prompts_today = (@state['prompts_today'] || []).count(today.to_s)
      max_prompts = @config.dig('triggers', 'max_prompts_per_day')

      prompts_today < max_prompts
    end

    # Project completion trigger: Detect git merge/push to main
    def project_completion_trigger?(context)
      return false unless @config.dig('triggers', 'project_completion')
      return false unless context[:git_event].is_a?(String)

      %w[merge push].any? { |event| context[:git_event].downcase.include?(event) }
    end

    def accumulation_message
      sessions = @state['session_count'] || 0
      threshold = @config.dig('triggers', 'accumulation_threshold') || 10
      <<~MSG
        📊 Session Milestone

        Sessions completed: #{sessions} (threshold: #{threshold})

        Consider crafting personal skills from your successful patterns.

        Run `/skill-craft` to review and extract patterns.
      MSG
    end

    def periodic_message
      days_since = (Date.today - Time.parse(@state['last_review']).to_date).to_i
      <<~MSG
        📅 Weekly Review

        It's been #{days_since} days since your last skill crafting session.

        Run `/skill-craft` to extract personal skills.
      MSG
    end

    def project_completion_message
      event = @state['git_event'] || 'project completion'
      <<~MSG
        🎉 Project Completion Detected

        #{event} completed successfully!

        Would you like to review and extract skills from this work?

        Run `/skill-craft` to start crafting.
      MSG
    end

    # Increment session counter
    def increment_session_count
      @state['session_count'] ||= 0
      @state['session_count'] += 1
      save_state
    end

    # Record prompt shown
    def record_prompt
      today = Date.today.to_s
      @state['prompts_today'] ||= []
      @state['prompts_today'] << today
      save_state
    end

    # Record review completed
    def record_review
      @state['last_review'] = Date.today.to_s
      @state['session_count'] = 0
      save_state
    end
  end
end
