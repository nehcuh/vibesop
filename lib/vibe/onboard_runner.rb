# frozen_string_literal: true

module Vibe
  # Guided 5-step onboarding for new users.
  #
  # Host requirements:
  #   @repo_root [String] — absolute path to the workflow repository root
  #
  # Dependencies:
  #   - Vibe::QuickstartRunner — Step 1 deployment
  module OnboardRunner
    STEPS = 5

    # Run guided onboarding
    # @param options [Hash] :skip_deploy to skip Step 1 when config already exists
    def run_onboard(options = {})
      puts "\n🚀 Vibe Onboarding — 5-step guided setup"
      puts '=' * 50

      # Step 1: Deploy base config
      unless options[:skip_deploy]
        puts "\n[1/#{STEPS}] Deploying base configuration..."
        run_quickstart(force: true)
      else
        puts "\n[1/#{STEPS}] Skipping deploy (--skip-deploy)"
      end

      # Step 2: Capture user role
      puts "\n[2/#{STEPS}] Recording your role..."
      role = onboard_prompt_role
      onboard_write_role(role) if role && !role.strip.empty?

      # Step 3: Doctor check
      puts "\n[3/#{STEPS}] Verifying installation..."
      run_doctor_command([])

      # Step 4: Show P0 skill summary
      puts "\n[4/#{STEPS}] Core skill: systematic-debugging"
      puts '─' * 40
      puts onboard_skill_summary

      # Step 5: Next steps
      puts "\n[5/#{STEPS}] You're set up! Next steps:"
      puts '─' * 40
      puts onboard_next_steps

      puts "\n✅ Onboarding complete. Run `vibe help` to explore all commands."
    end

    private

    def onboard_prompt_role
      print '  Describe your role in one sentence (e.g. "Full-stack engineer"): '
      $stdout.flush
      line = $stdin.gets
      line ? line.chomp : nil
    rescue Interrupt
      nil
    end

    def onboard_write_role(role)
      session_path = File.expand_path('~/.claude/memory/session.md')
      FileUtils.mkdir_p(File.dirname(session_path))
      entry = "\n## User Role\n#{role}\n"
      File.open(session_path, 'a') { |f| f.write(entry) }
      puts "  ✓ Role saved to ~/.claude/memory/session.md"
    rescue StandardError => e
      warn "  Could not save role: #{e.message}"
    end

    def onboard_skill_summary
      <<~SUMMARY
        systematic-debugging — Find root cause before attempting fixes.

        Phases:
          1. Observe   — reproduce the failure, read the error in full
          2. Locate    — identify the file/line/call-site responsible
          3. Hypothesize — form a single root-cause theory
          4. Fix        — change the minimum code needed
          5. Verify     — run tests/commands to confirm the fix

        Trigger: any test/build/lint failure, or when stuck >15 min.
        Docs: ~/.claude/skills/systematic-debugging/
      SUMMARY
    end

    def onboard_next_steps
      <<~STEPS
        • vibe doctor          — re-run environment check anytime
        • vibe instinct status — view learned patterns after a few sessions
        • vibe quickstart      — re-deploy config if you change machines
        • /session-end         — wrap up each session (saves memory + commits)
        • /systematic-debugging — structured debugging when things break
      STEPS
    end
  end
end
