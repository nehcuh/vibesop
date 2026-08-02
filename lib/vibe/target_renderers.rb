# frozen_string_literal: true

require_relative 'config_driven_renderers'

module Vibe
  # Per-target file renderers that write generated output to disk.
  #
  # This module now uses configuration-driven rendering via ConfigDrivenRenderers
  # for supported platforms, while maintaining backward compatibility.
  #
  # Host requirements:
  #   @repo_root [String] — absolute path to the workflow repository root
  #
  # Depends on methods from:
  #   Vibe::Utils          — write_json, format_backtick_list
  #   Vibe::DocRendering   — render_*_doc, bullet_*, filtered_policies,
  #                          mandatory/optional_skills
  #   Vibe::NativeConfigs  — claude_settings_config, opencode_config
  #   Vibe::OverlaySupport — overlay_sentence
  #   Vibe::PathSafety     — copy_tree_contents
  #   Vibe::ConfigDrivenRenderers — modern config-driven platform rendering
  module TargetRenderers
    include Vibe::ConfigDrivenRenderers

    COPY_RUNTIME_ENTRIES = %w[rules docs skills agents commands memory].freeze

    def write_target_docs(output_dir, manifest, doc_types)
      doc_types.each do |type|
        filename = "#{type.to_s.gsub('_', '-')}.md"
        # Special cases for filenames
        filename = 'behavior-policies.md' if type == :behavior
        filename = 'execution-policy.md' if type == :execution_policy
        filename = 'execution.md' if type == :execution

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
                  else
                    raise Vibe::Error, "Unknown doc type: #{type}"
                  end

        File.write(File.join(output_dir, filename), content)
      end
    end

    # Render Claude Code configuration
    # Now uses configuration-driven rendering for better maintainability
    def render_claude(output_root, manifest, project_level: false)
      render_platform(output_root, manifest, 'claude-code', project_level: project_level)
    end

    # Render OpenCode configuration
    # Now uses configuration-driven rendering for better maintainability
    def render_opencode(output_root, manifest, project_level: false)
      render_platform(output_root, manifest, 'opencode', project_level: project_level)
    end

    def render_opencode_project_md(manifest)
      render_generic_project_md('opencode', manifest)
    end

    def render_target_entrypoint_md(target_name, manifest, extra_sections: nil)
      sp_info = verify_superpowers
      rtk_info = verify_rtk
      integrations = render_integrations_section(target_name, sp_info, rtk_info)

      <<~MD
        # Vibe workflow for #{target_name}

        Generated from the portable `core/` spec with profile `#{manifest['profile']}`.#{integrations}
        Applied overlay: #{overlay_sentence(manifest)}

        #{target_entrypoint_intent(target_name)}

        ## Non-negotiable rules

        #{bullet_policy_summary(filtered_policies(manifest, %w[always_on routing safety]))}

        ## Capability routing

        #{bullet_mapping(manifest['profile_mapping'])}

        ## Mandatory portable skills

        #{bullet_skill_summary(mandatory_skills(manifest))}

        #{extra_sections}

        ## Safety floor

        #{bullet_target_actions(manifest)}
      MD
    end

    private

    def render_claude_project_md(manifest)
      config_dir = platform_config_dir('claude-code')
      <<~MD
        # Project Claude Code Configuration

        Generated from the portable `core/` spec with profile `#{manifest['profile']}`.
        Applied overlay: #{overlay_sentence(manifest)}

        Global workflow rules are loaded from `#{config_dir}/`. This file adds project-specific context only.

        ## Project Context

        <!-- Describe your project: tech stack, architecture, key constraints -->

        ## Project-specific rules

        <!-- Add rules that apply only to this project -->

        ## Reference docs

        Supporting notes are under `.vibe/claude-code/`:
        - `behavior-policies.md` — portable behavior baseline
        - `safety.md` — safety policy
        - `task-routing.md` — task complexity routing
        - `test-standards.md` — testing requirements
      MD
    end

    def target_entrypoint_intent(target_name)
      case target_name
      when 'OpenCode'
        <<~TEXT.chomp
          Project rules are split into modular instruction files loaded from `opencode.json`.

          Keep repository files as the single source of truth, verify before claiming completion, and follow the generated safety policy.
        TEXT
      else
        'Keep repository files as the SSOT, verify before claiming completion, ' \
          'and follow the generated routing + safety rules.'
      end
    end

    def superpowers_skill_list
      doc = superpowers_doc
      Array(doc['skills']).map { |s| { 'id' => s['id'], 'intent' => s['intent'] } }
    rescue Vibe::ConfigurationError, Errno::ENOENT
      []
    end

    def format_superpowers_skill_bullets
      skills = superpowers_skill_list
      return '' if skills.empty?

      skills.map { |s| "- `superpowers/#{s['id']}` — #{s['intent']}" }.join("\n")
    end

    # Data-driven templates for integration section rendering
    # Reduces conditional complexity and makes target-specific customization declarative
    INTEGRATION_TEMPLATES = {
      default: {
        superpowers: {
          header_style: :nested,
          install_note_template: :generic,
          show_benefits: false,
          show_full_details: false
        },
        rtk: {
          header_style: :nested,
          install_template: :generic,
          show_benefits: false,
          show_version: true
        }
      }
    }.freeze

    # Installation note templates for Superpowers
    SUPERPOWERS_INSTALL_TEMPLATES = {
      generic: ->(target_name) { <<~NOTE.chomp }
        # Clone the repository
        git clone https://github.com/obra/superpowers ~/.config/skills/superpowers

        # For #{target_name}, manually register the skills in your tool's skill system
        # or use the skill files from ~/.config/skills/superpowers/skills/
      NOTE
    }.freeze

    # RTK installation templates
    RTK_INSTALL_TEMPLATES = {
      generic: <<~CMD.chomp
        brew install rtk

        # Or build from source
        cargo install --git https://github.com/rtk-ai/rtk
      CMD
    }.freeze

    def render_integrations_section(target_name, sp_info, rtk_info)
      sections = []
      skill_bullets = format_superpowers_skill_bullets

      # Get target-specific template configuration
      target_key = target_name.downcase.gsub(' ', '-')
      template_config = INTEGRATION_TEMPLATES[target_key] ||
                        INTEGRATION_TEMPLATES[:default]

      # Render Superpowers section
      sections << render_superpowers_integration(target_name, sp_info, skill_bullets,
                                                 template_config[:superpowers])

      # Render RTK section
      sections << render_rtk_integration(target_name, rtk_info, template_config[:rtk])

      sections.compact.join("\n\n")
    end

    def render_superpowers_integration(target_name, sp_info, skill_bullets, config)
      return nil if skill_bullets.empty?

      is_standalone = config[:header_style] == :standalone

      if sp_info[:installed]
        render_installed_superpowers(target_name, sp_info, skill_bullets, is_standalone)
      else
        render_not_installed_superpowers(target_name, skill_bullets, config,
                                         is_standalone)
      end
    end

    def render_installed_superpowers(_target_name, sp_info, skill_bullets, is_standalone)
      location = sp_info[:location] || 'Unknown'

      header = if is_standalone
                 '## Superpowers Skill Pack Integration'
               else
                 "## Optional Integrations\n\n### Superpowers Skill Pack"
               end

      <<~SP
        #{header}

        **Status**: ✅ Installed (#{location})

        The following Superpowers skills are available:
        #{skill_bullets}
      SP
    end

    def render_not_installed_superpowers(target_name, skill_bullets, config,
                                         is_standalone)
      target_display = " for #{target_name}"

      header = if is_standalone
                 '## Optional: Superpowers Skill Pack'
               else
                 "## Optional Integrations\n\n### Superpowers Skill Pack"
               end

      install_note = get_superpowers_install_note(config[:install_note_template],
                                                  target_name)
      full_details_note = if config[:show_full_details]
                            "\nSee `core/integrations/superpowers.yaml` for full details."
                          else
                            ''
                          end

      <<~SP
        #{header}

        **Status**: ❌ Not installed

        Superpowers provides advanced skills for design refinement, TDD, debugging, and more.

        **Installation#{target_display}**:
        ```bash
        #{install_note}
        ```

        **Available skills#{config[:show_full_details] ? ' after installation' : ''}**:
        #{skill_bullets}#{full_details_note}
      SP
    end

    def get_superpowers_install_note(template_key, target_name)
      template = SUPERPOWERS_INSTALL_TEMPLATES[template_key]
      return template.call(target_name) if template.is_a?(Proc)

      template
    end

    def render_rtk_integration(target_name, rtk_info, config)
      if rtk_info[:installed]
        render_installed_rtk(target_name, rtk_info, config)
      else
        render_not_installed_rtk(target_name, config)
      end
    end

    def render_installed_rtk(_target_name, rtk_info, config)
      is_standalone = config[:header_style] == :standalone

      hook_status = rtk_info[:hook_configured] ? '✅ Configured' : '⚠️ Not configured'

      header = if is_standalone
                 '## RTK Token Optimizer'
               else
                 '### RTK Token Optimizer'
               end

      config_note = if !rtk_info[:hook_configured]
                      "\n\n**To configure**: Run `rtk init --global`"
                    else
                      ''
                    end

      <<~RTK
        #{header}

        **Status**: ✅ Installed
        **Hook**: #{hook_status}
        **Version**: #{rtk_info[:version] || 'Unknown'}

        RTK reduces token consumption by 60-90% on common commands.#{config_note}
      RTK
    end

    def render_not_installed_rtk(target_name, config)
      is_standalone = config[:header_style] == :standalone

      header = if is_standalone
                 '## Optional: RTK Token Optimizer'
               else
                 '### RTK Token Optimizer'
               end

      install_cmd = RTK_INSTALL_TEMPLATES[config[:install_template]]
      config_step = "\n\n# Then configure\nrtk init --global"
      generic_note = "\n\n\n**Note**: RTK works best with Claude Code. " \
                     "For #{target_name}, you may need to manually prefix " \
                     'commands with `rtk`.'

      benefits_section = if config[:show_benefits]
                           <<~BENEFITS


                             **Benefits**:
                             - 60-90% token reduction on command outputs
                             - Less than 10ms overhead per command
                             - Works transparently via hooks

                             See `core/integrations/rtk.yaml` for full details.
                           BENEFITS
                         else
                           generic_note
                         end

      <<~RTK
        #{header}

        **Status**: ❌ Not installed

        RTK is a CLI proxy that reduces LLM token consumption by 60-90% on common development commands.

        **Installation**:
        ```bash
        # macOS/Linux with Homebrew
        #{install_cmd}#{config_step}
        ```#{benefits_section}
      RTK
    end
  end
end
