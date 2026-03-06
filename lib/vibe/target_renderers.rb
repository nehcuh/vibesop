# frozen_string_literal: true

module Vibe
  # Per-target file renderers that write generated output to disk.
  #
  # Host requirements:
  #   @repo_root [String] — absolute path to the workflow repository root
  #
  # Depends on methods from:
  #   Vibe::Utils          — write_json, format_backtick_list
  #   Vibe::DocRendering   — render_*_doc, bullet_*, filtered_policies, mandatory/optional_skills
  #   Vibe::NativeConfigs  — claude_settings_config, cursor_cli_permissions_config, opencode_config
  #   Vibe::OverlaySupport — overlay_sentence
  #   Vibe::PathSafety     — copy_tree_contents
  module TargetRenderers
    COPY_RUNTIME_ENTRIES = %w[CLAUDE.md rules docs skills agents commands memory patterns.md].freeze

    def render_claude(output_root, manifest)
      COPY_RUNTIME_ENTRIES.each do |entry|
        source = File.join(@repo_root, entry)
        unless File.exist?(source)
          $stderr.puts "Warning: skipping missing runtime entry: #{entry}"
          next
        end

        destination = File.join(output_root, entry)

        if File.directory?(source)
          FileUtils.mkdir_p(destination)
          copy_tree_contents(source, destination)
        else
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(source, destination)
        end
      end

      write_json(File.join(output_root, "settings.json"), claude_settings_config(manifest))

      claude_dir = File.join(output_root, ".vibe", "claude-code")
      FileUtils.mkdir_p(claude_dir)
      File.write(File.join(claude_dir, "README.md"), <<~MD)
        # Claude Code target

        This output is intended to be copied into a Claude Code config directory such as `~/.claude`.

        Included runtime assets:
        - `CLAUDE.md`
        - `rules/`
        - `docs/`
        - `skills/`
        - `agents/`
        - `commands/`
        - `memory/`
        - `patterns.md`
        - `settings.json`

        Active profile: `#{manifest["profile"]}`
        Applied overlay: #{overlay_sentence(manifest)}
        Generated summary: `.vibe/target-summary.md`
      MD
      File.write(File.join(claude_dir, "behavior-policies.md"), render_behavior_doc(manifest))
      File.write(File.join(claude_dir, "safety.md"), render_safety_doc(manifest))
    end

    def render_codex(output_root, manifest)
      codex_dir = File.join(output_root, ".vibe", "codex-cli")
      FileUtils.mkdir_p(codex_dir)
      File.write(File.join(codex_dir, "behavior-policies.md"), render_behavior_doc(manifest))
      File.write(File.join(codex_dir, "routing.md"), render_routing_doc(manifest))
      File.write(File.join(codex_dir, "skills.md"), render_skills_doc(manifest))
      File.write(File.join(codex_dir, "safety.md"), render_safety_doc(manifest))
      File.write(File.join(codex_dir, "execution-policy.md"), render_execution_policy_doc(manifest))

      File.write(File.join(output_root, "AGENTS.md"), <<~MD)
        # Vibe workflow for Codex CLI

        Generated from the portable `core/` spec with profile `#{manifest["profile"]}`.
        Applied overlay: #{overlay_sentence(manifest)}

        ## Non-negotiable rules

        #{bullet_policy_summary(filtered_policies(manifest, %w[always_on routing safety]))}

        ## Capability routing

        #{bullet_mapping(manifest["profile_mapping"])}

        ## Mandatory portable skills

        #{bullet_skill_summary(mandatory_skills(manifest))}

        ## Execution model

        - Use `.vibe/codex-cli/execution-policy.md` for the default flow and review protocol.
        - Use `.vibe/codex-cli/routing.md` when task routing is ambiguous.
        - Use `.vibe/codex-cli/safety.md` when a task touches risky behavior or permissions.
        - Use `.vibe/codex-cli/behavior-policies.md` for the portable behavior baseline.

        ## Safety floor

        #{bullet_target_actions(manifest)}
      MD
    end

    def render_cursor(output_root, manifest)
      cursor_rules_dir = File.join(output_root, ".cursor", "rules")
      cursor_support_dir = File.join(output_root, ".vibe", "cursor")
      FileUtils.mkdir_p(cursor_rules_dir)
      FileUtils.mkdir_p(cursor_support_dir)

      File.write(File.join(output_root, "AGENTS.md"), <<~MD)
        # Vibe workflow for Cursor

        Generated from the portable `core/` spec with profile `#{manifest["profile"]}`.
        Applied overlay: #{overlay_sentence(manifest)}

        Primary behavior is defined in `.cursor/rules/*.mdc`, with supporting notes under `.vibe/cursor/`.

        Keep repository files as the SSOT, verify before claiming completion, and follow the generated routing + safety rules.
      MD

      write_json(File.join(output_root, ".cursor", "cli.json"), cursor_cli_permissions_config(manifest))
      File.write(File.join(cursor_support_dir, "behavior-policies.md"), render_behavior_doc(manifest))
      File.write(File.join(cursor_support_dir, "routing.md"), render_routing_doc(manifest))
      File.write(File.join(cursor_support_dir, "safety.md"), render_safety_doc(manifest))
      File.write(File.join(cursor_support_dir, "skills.md"), render_skills_doc(manifest))

      File.write(File.join(cursor_rules_dir, "00-vibe-core.mdc"), <<~MDC)
        ---
        description: Generated portable workflow core
        alwaysApply: true
        ---

        # Portable workflow core

        #{bullet_policy_summary(filtered_policies(manifest, ["always_on"]))}

        ## Mandatory skills

        #{bullet_skill_summary(mandatory_skills(manifest))}
      MDC

      File.write(File.join(cursor_rules_dir, "05-vibe-routing.mdc"), <<~MDC)
        ---
        description: Generated portable routing policy
        alwaysApply: true
        ---

        # Capability routing

        #{bullet_policy_summary(filtered_policies(manifest, ["routing"]))}

        ## Active mapping

        #{bullet_mapping(manifest["profile_mapping"])}
      MDC

      File.write(File.join(cursor_rules_dir, "08-vibe-safety.mdc"), <<~MDC)
        ---
        description: Generated portable safety policy
        alwaysApply: true
        ---

        # Safety policy

        #{bullet_policy_summary(filtered_policies(manifest, ["safety"]))}

        ## Target actions

        #{bullet_target_actions(manifest)}

        See `.cursor/cli.json` and `.vibe/cursor/safety.md` for the generated safety baseline.
      MDC

      File.write(File.join(cursor_rules_dir, "20-vibe-optional-skills.mdc"), <<~MDC)
        ---
        description: Portable optional skill and workflow reference
        alwaysApply: false
        ---

        # Optional workflow guidance

        #{bullet_policy_summary(filtered_policies(manifest, ["optional"]))}

        ## Optional skills

        #{bullet_skill_summary(optional_skills(manifest))}
      MDC
    end

    def render_opencode(output_root, manifest)
      opencode_dir = File.join(output_root, ".vibe", "opencode")
      FileUtils.mkdir_p(opencode_dir)

      File.write(File.join(opencode_dir, "behavior-policies.md"), render_behavior_doc(manifest))
      File.write(File.join(opencode_dir, "general.md"), render_general_doc(manifest))
      File.write(File.join(opencode_dir, "routing.md"), render_routing_doc(manifest))
      File.write(File.join(opencode_dir, "skills.md"), render_skills_doc(manifest))
      File.write(File.join(opencode_dir, "safety.md"), render_safety_doc(manifest))
      File.write(File.join(opencode_dir, "execution.md"), render_execution_policy_doc(manifest))

      File.write(File.join(output_root, "AGENTS.md"), <<~MD)
        # Vibe workflow for OpenCode

        Generated from the portable `core/` spec with profile `#{manifest["profile"]}`.
        Applied overlay: #{overlay_sentence(manifest)}

        Project rules are split into modular instruction files loaded from `opencode.json`.

        Keep repository files as the single source of truth, verify before claiming completion, and follow the generated safety policy.
      MD

      write_json(File.join(output_root, "opencode.json"), opencode_config(manifest))
    end

    def render_warp(output_root, manifest)
      warp_dir = File.join(output_root, ".vibe", "warp")
      FileUtils.mkdir_p(warp_dir)

      File.write(File.join(output_root, "WARP.md"), <<~MD)
        # Vibe workflow for Warp

        Generated from the portable `core/` spec with profile `#{manifest["profile"]}`.
        Applied overlay: #{overlay_sentence(manifest)}

        This file is intended as the Warp project rule entrypoint for the repository.

        ## Non-negotiable rules

        #{bullet_policy_summary(filtered_policies(manifest, %w[always_on routing safety]))}

        ## Capability routing

        #{bullet_mapping(manifest["profile_mapping"])}

        ## Mandatory portable skills

        #{bullet_skill_summary(mandatory_skills(manifest))}

        ## Supporting files

        - Use `.vibe/warp/behavior-policies.md` for the full portable behavior baseline.
        - Use `.vibe/warp/routing.md` for tier routing and profile mapping.
        - Use `.vibe/warp/safety.md` for security-sensitive work and escalation policy.
        - Use `.vibe/warp/skills.md` for portable skill references.
        - Use `.vibe/warp/workflow-notes.md` for conservative workflow guidance in Warp.

        ## Safety floor

        #{bullet_target_actions(manifest)}
      MD

      File.write(File.join(warp_dir, "behavior-policies.md"), render_behavior_doc(manifest))
      File.write(File.join(warp_dir, "routing.md"), render_routing_doc(manifest))
      File.write(File.join(warp_dir, "skills.md"), render_skills_doc(manifest))
      File.write(File.join(warp_dir, "safety.md"), render_safety_doc(manifest))
      File.write(File.join(warp_dir, "workflow-notes.md"), render_warp_workflow_notes_doc(manifest))
    end
  end
end
