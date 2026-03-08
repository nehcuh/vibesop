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

    def write_target_docs(output_dir, manifest, doc_types)
      doc_types.each do |type|
        filename = "#{type.to_s.gsub('_', '-')}.md"
        # Special cases for filenames
        filename = "behavior-policies.md" if type == :behavior
        filename = "execution-policy.md" if type == :execution_policy
        filename = "execution.md" if type == :execution

        content = case type
                  when :behavior then render_behavior_doc(manifest)
                  when :routing then render_routing_doc(manifest)
                  when :safety then render_safety_doc(manifest)
                  when :skills then render_skills_doc(manifest)
                  when :task_routing then render_task_routing_doc(manifest)
                  when :test_standards then render_test_standards_doc(manifest)
                  when :execution_policy then render_execution_policy_doc(manifest)
                  when :execution then render_execution_policy_doc(manifest)
                  when :general then render_general_doc(manifest)
                  when :workflow_notes then render_warp_workflow_notes_doc(manifest)
                  else
                    raise Vibe::Error, "Unknown doc type: #{type}"
                  end

        File.write(File.join(output_dir, filename), content)
      end
    end

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

      # Conditionally include skill-triggers.md with Superpowers integration info
      superpowers_status = detect_superpowers
      if superpowers_status != :not_installed
        skill_triggers_source = File.join(@repo_root, "rules", "skill-triggers.md")
        skill_triggers_dest = File.join(output_root, "rules", "skill-triggers.md")

        if File.exist?(skill_triggers_source)
          content = File.read(skill_triggers_source)

          # Append Superpowers integration section
          superpowers_section = generate_superpowers_section(superpowers_status, manifest)
          enhanced_content = superpowers_section.empty? ? content : content + "\n" + superpowers_section

          File.write(skill_triggers_dest, enhanced_content)
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
      write_target_docs(claude_dir, manifest, %i[behavior safety task_routing test_standards])
    end

    def render_codex(output_root, manifest)
      codex_dir = File.join(output_root, ".vibe", "codex-cli")
      FileUtils.mkdir_p(codex_dir)
      write_target_docs(codex_dir, manifest, %i[behavior routing skills safety execution_policy task_routing test_standards])

      extra = <<~MD
        ## Execution model

        - Use `.vibe/codex-cli/execution-policy.md` for the default flow and review protocol.
        - Use `.vibe/codex-cli/routing.md` when task routing is ambiguous.
        - Use `.vibe/codex-cli/safety.md` when a task touches risky behavior or permissions.
        - Use `.vibe/codex-cli/behavior-policies.md` for the portable behavior baseline.
      MD

      File.write(File.join(output_root, "AGENTS.md"), render_target_entrypoint_md("Codex CLI", manifest, extra_sections: extra))
    end

    def render_cursor(output_root, manifest)
      cursor_rules_dir = File.join(output_root, ".cursor", "rules")
      cursor_support_dir = File.join(output_root, ".vibe", "cursor")
      FileUtils.mkdir_p(cursor_rules_dir)
      FileUtils.mkdir_p(cursor_support_dir)

      File.write(File.join(output_root, "AGENTS.md"), render_target_entrypoint_md("Cursor", manifest))

      write_json(File.join(output_root, ".cursor", "cli.json"), cursor_cli_permissions_config(manifest))
      write_target_docs(cursor_support_dir, manifest, %i[behavior routing safety skills task_routing test_standards])

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
      write_target_docs(opencode_dir, manifest, %i[behavior general routing skills safety execution])

      File.write(File.join(output_root, "AGENTS.md"), render_target_entrypoint_md("OpenCode", manifest))

      write_json(File.join(output_root, "opencode.json"), opencode_config(manifest))
    end

    def render_warp(output_root, manifest)
      warp_dir = File.join(output_root, ".vibe", "warp")
      FileUtils.mkdir_p(warp_dir)

      extra = <<~MD
        ## Supporting files

        - Use `.vibe/warp/behavior-policies.md` for the full portable behavior baseline.
        - Use `.vibe/warp/routing.md` for tier routing and profile mapping.
        - Use `.vibe/warp/safety.md` for security-sensitive work and escalation policy.
        - Use `.vibe/warp/skills.md` for portable skill references.
        - Use `.vibe/warp/task-routing.md` for task complexity classification and process requirements.
        - Use `.vibe/warp/test-standards.md` for test coverage standards by complexity.
        - Use `.vibe/warp/workflow-notes.md` for conservative workflow guidance in Warp.
      MD

      File.write(File.join(output_root, "WARP.md"), render_target_entrypoint_md("Warp", manifest, extra_sections: extra))

      write_target_docs(warp_dir, manifest, %i[behavior routing skills safety task_routing test_standards workflow_notes])
    end

    def render_antigravity(output_root, manifest)
      ag_dir = File.join(output_root, ".vibe", "antigravity")
      FileUtils.mkdir_p(ag_dir)

      extra = <<~MD
        ## Target requirements

        - Understand task tracking files and project documentation before execution.
        - Treat `.vibe/antigravity/` documents as authoritative framework conventions.
        - Escalations and security policy constraints are detailed in `.vibe/antigravity/safety.md`.
      MD

      File.write(File.join(output_root, "AGENTS.md"), render_target_entrypoint_md("Antigravity", manifest, extra_sections: extra))

      write_target_docs(ag_dir, manifest, %i[behavior routing safety skills task_routing test_standards])
    end

    def render_vscode(output_root, manifest)
      vscode_dir = File.join(output_root, ".vscode")
      vibe_dir = File.join(output_root, ".vibe", "vscode")
      FileUtils.mkdir_p(vscode_dir)
      FileUtils.mkdir_p(vibe_dir)

      File.write(File.join(output_root, "AGENTS.md"), render_target_entrypoint_md("VS Code", manifest))

      write_target_docs(vibe_dir, manifest, %i[behavior routing safety skills task_routing test_standards])

      write_json(File.join(vscode_dir, "settings.json"), vscode_settings_config(manifest))
    end

    def render_kimi_code(output_root, manifest)
      kimi_skills_dir = File.join(output_root, ".kimi", "skills")
      kimi_support_dir = File.join(output_root, ".vibe", "kimi-code")
      FileUtils.mkdir_p(kimi_skills_dir)
      FileUtils.mkdir_p(kimi_support_dir)

      extra = <<~MD
        ## Skills

        Skills are defined in `.kimi/skills/*/SKILL.md` files.

        ## Supporting documentation

        - `.vibe/kimi-code/behavior-policies.md` — Full behavior policy baseline
        - `.vibe/kimi-code/routing.md` — Capability tier routing reference
        - `.vibe/kimi-code/safety.md` — Security policy and escalation guidance
        - `.vibe/kimi-code/skills.md` — Portable skill registry reference
        - `.vibe/kimi-code/task-routing.md` — Task complexity classification
        - `.vibe/kimi-code/test-standards.md` — Test coverage requirements
      MD

      File.write(File.join(output_root, "KIMI.md"), render_target_entrypoint_md("Kimi Code", manifest, extra_sections: extra))

      # Generate supporting documentation
      write_target_docs(kimi_support_dir, manifest, %i[behavior routing safety skills task_routing test_standards])

      # Generate SKILL.md files for mandatory skills
      manifest.fetch("skills", []).each do |skill|
        next unless skill["trigger_mode"] == "mandatory"

        skill_dir = File.join(kimi_skills_dir, skill["id"])
        FileUtils.mkdir_p(skill_dir)

        allowed_tools = skill.fetch("allowed_tools", ["Read", "Grep", "Glob"])
        tool_list = allowed_tools.join(", ")

        File.write(File.join(skill_dir, "SKILL.md"), <<~SKILL)
          ---
          name: #{skill["id"]}
          description: #{skill["intent"]} (#{skill["severity"] || "P1"})
          version: 1.0.0
          allowed-tools:
          #{allowed_tools.map { |t| "  - #{t}" }.join("\n")}
          ---

          # #{skill["name"] || skill["id"].split("-").map(&:capitalize).join(" ")}

          #{skill["description"] || skill["intent"]}

          ## When to use

          #{skill["intent"]}

          ## Instructions

          #{skill["how_to_invoke"] || "Follow the workflow defined in this skill."}

          ---
          *Generated from portable skill registry*
        SKILL
      end

      # Generate a README for the kimi skills directory
      File.write(File.join(kimi_skills_dir, "README.md"), <<~MD)
        # Kimi Code Skills

        This directory contains Vibe workflow skills for Kimi Code.

        ## Usage

        ```bash
        # List available skills
        kimi skill list

        # Run a specific skill
        kimi skill run session-end
        ```

        ## Available Skills

        #{manifest.fetch("skills", []).select { |s| s["trigger_mode"] == "mandatory" }.map { |s| "- `#{s['id']}` — #{s['intent']}" }.join("\n")}
      MD
    end



    def render_target_entrypoint_md(target_name, manifest, extra_sections: nil)
      superpowers_status = detect_superpowers
      rtk_info = verify_rtk
      integrations = render_integrations_section(target_name, superpowers_status, rtk_info)

      <<~MD
        # Vibe workflow for #{target_name}

        Generated from the portable `core/` spec with profile `#{manifest["profile"]}`.#{integrations}
        Applied overlay: #{overlay_sentence(manifest)}

        #{target_entrypoint_intent(target_name)}

        ## Non-negotiable rules

        #{bullet_policy_summary(filtered_policies(manifest, %w[always_on routing safety]))}

        ## Capability routing

        #{bullet_mapping(manifest["profile_mapping"])}

        ## Mandatory portable skills

        #{bullet_skill_summary(mandatory_skills(manifest))}

        #{extra_sections}

        ## Safety floor

        #{bullet_target_actions(manifest)}
      MD
    end

    private

    def target_entrypoint_intent(target_name)
      case target_name
      when "Warp" then "This file is intended as the Warp project rule entrypoint for the repository."
      when "Kimi Code" then "This file serves as the project entrypoint for Kimi Code."
      when "Cursor", "Antigravity" then "Primary behavior is defined here, with supporting notes under `.vibe/#{target_name.downcase}/`.\n\nKeep repository files as the SSOT, verify before claiming completion, and follow the generated routing + safety rules."
      when "VS Code" then "VS Code (Copilot Chat) instructions use these generated guidelines as the baseline."
      when "OpenCode" then "Project rules are split into modular instruction files loaded from `opencode.json`.\n\nKeep repository files as the single source of truth, verify before claiming completion, and follow the generated safety policy."
      else "Keep repository files as the SSOT, verify before claiming completion, and follow the generated routing + safety rules."
      end
    end

    def superpowers_skill_list
      yaml_path = File.join(@repo_root, "core", "integrations", "superpowers.yaml")
      return [] unless File.exist?(yaml_path)

      doc = YAML.load_file(yaml_path)
      Array(doc["skills"]).map { |s| { "id" => s["id"], "intent" => s["intent"] } }
    end

    def format_superpowers_skill_bullets
      skills = superpowers_skill_list
      return "" if skills.empty?

      skills.map { |s| "- `superpowers/#{s['id']}` — #{s['intent']}" }.join("\n")
    end

    def render_integrations_section(target_name, superpowers_status, rtk_info)
      sections = []
      is_kimi = target_name == "Kimi Code"
      is_warp = target_name == "Warp"
      skill_bullets = format_superpowers_skill_bullets

      # Superpowers section
      if superpowers_status == :not_installed
        header = is_kimi ? "## Optional: Superpowers Skill Pack" : "## Optional Integrations\n\n### Superpowers Skill Pack"
        install_note = if is_kimi
                         "Option 1: Manual clone\ngit clone https://github.com/obra/superpowers ~/superpowers\n\n# Then create symlinks to your skills directory\nln -s ~/superpowers/skills/* ~/.kimi/skills/  # Adjust path as needed"
                       elsif is_warp
                         "Clone the repository\ngit clone https://github.com/obra/superpowers ~/superpowers\n\n# In Warp, manually add the skill paths or use as reference"
                       else
                         "Clone the repository\ngit clone https://github.com/obra/superpowers ~/superpowers\n\n# For #{target_name}, manually register the skills in your tool's skill system\n# or use the skill files from ~/superpowers/skills/"
                       end

        sections << <<~SP
          #{header}

          **Status**: ❌ Not installed

          Superpowers provides advanced skills for design refinement, TDD, debugging, and more.

          **Installation#{is_kimi ? "" : " for #{target_name}"}**:
          ```bash
          #{install_note}
          ```

          **Available skills#{is_kimi ? " after installation" : ""}**:
          #{skill_bullets}
          #{is_kimi ? "\nSee `core/integrations/superpowers.yaml` for full details." : ""}
        SP
      else
        location = case superpowers_status
                   when :claude_plugin then "~/.claude/plugins/superpowers"
                   when :skills_symlink then "~/.claude/skills/superpowers-*"
                   when :local_clone then "~/superpowers"
                   when :cursor_plugin then (target_name == "Cursor" ? "Installed" : "Cursor plugins")
                   else "Installed"
                   end
        header = is_kimi ? "## Superpowers Skill Pack Integration" : "## Optional Integrations\n\n### Superpowers Skill Pack"
        sections << <<~SP
          #{header}

          **Status**: ✅ Installed (#{location})

          The following Superpowers skills are available:
          #{skill_bullets}
        SP
      end

      # RTK section
      if rtk_info[:installed]
        hook_status = rtk_info[:hook_configured] ? "✅ Configured" : "⚠️ Not configured"
        header = is_kimi ? "## RTK Token Optimizer" : "### RTK Token Optimizer"
        warp_note = is_warp ? "\n**For Warp**: Manually prefix commands with `rtk`, e.g., `rtk git status`" : ""
        config_note = (!is_warp && !rtk_info[:hook_configured]) ? "\n\n**To configure**: Run `rtk init --global`" : ""

        sections << <<~RTK
          #{header}

          **Status**: ✅ Installed
          #{is_warp ? "" : "**Hook**: #{hook_status}\n"}**Version**: #{rtk_info[:version] || "Unknown"}

          RTK reduces token consumption by 60-90% on common commands.#{warp_note}#{config_note}
        RTK
      else
        header = is_kimi ? "## Optional: RTK Token Optimizer" : "### RTK Token Optimizer"
        install_cmd = is_warp ? "brew install rtk" : "brew install rtk\n\n# Or build from source\ncargo install --git https://github.com/rtk-ai/rtk"
        config_step = is_warp ? "" : "\n\n# Then configure\nrtk init --global"
        warp_note = is_warp ? "\n**For Warp**: Manually prefix commands with `rtk`, e.g., `rtk git status`" : ""
        generic_note = (!is_kimi && !is_warp) ? "\n\n**Note**: RTK works best with Claude Code. For #{target_name}, you may need to manually prefix commands with `rtk`." : ""

        sections << <<~RTK
          #{header}

          **Status**: ❌ Not installed

          RTK is a CLI proxy that reduces LLM token consumption by 60-90% on common development commands#{is_kimi ? " (git, npm, pytest, etc.)" : ""}.

          **Installation**:
          ```bash
          # macOS/Linux with Homebrew
          #{install_cmd}#{config_step}
          ```
          #{is_kimi ? "\n**Benefits**:\n- 60-90% token reduction on command outputs\n- Less than 10ms overhead per command\n- Works transparently via hooks\n\nSee `core/integrations/rtk.yaml` for full details." : "#{warp_note}#{generic_note}"}
        RTK
      end

      sections.join("\n")
    end

    private

    def generate_superpowers_section(status, manifest)
      manifest_skills = Array(manifest["skills"]).select { |skill| skill["namespace"] == "superpowers" }
      return "" if manifest_skills.empty?

      location = case status
                 when :claude_plugin then "~/.claude/plugins/superpowers"
                 when :skills_symlink then "~/.claude/skills/superpowers-*"
                 when :local_clone then "~/superpowers"
                 when :cursor_plugin then "Cursor plugins"
                 else "Unknown"
                 end

      header = <<~MD

        ## Superpowers Skill Pack Integration

        **Status**: ✅ Installed (#{location})

        The following portable Superpowers skills are available for on-demand invocation:

        | Portable skill | Trigger mode | Description |
        |----------------|--------------|-------------|
      MD
      rows = manifest_skills.map do |skill|
        "| `#{skill['id']}` | `#{skill['trigger_mode']}` | #{skill['intent']} |"
      end.join("\n")

      footer = <<~MD


        **Usage**: `core/skills/registry.yaml` is the SSOT for portable skill IDs. The installed Superpowers pack may expose different native skill names.

        **Security**: All Superpowers skills have been reviewed and are considered safe for use.
        See `core/integrations/superpowers.yaml` for full skill definitions.
      MD

      header + rows + footer
    end
  end
end
