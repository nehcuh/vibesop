# frozen_string_literal: true

module Vibe
  # Target-specific native configuration builders for Claude Code settings.json
  # and OpenCode opencode.json.
  #
  # Depends on methods from:
  #   Vibe::Utils — deep_merge
  module NativeConfigs
    def base_claude_settings_config
      {
        'permissions' => {
          'defaultMode' => 'default',
          'disableBypassPermissionsMode' => 'disable',
          'ask' => [
            'Bash(curl:*)',
            'Bash(wget:*)',
            'Bash(scp:*)',
            'Bash(rsync:*)',
            'Bash(git push:*)',
            'Bash(npm publish:*)',
            'Bash(base64:*)',
            'Bash(eval:*)',
            'Bash(exec:*)',
            'WebFetch',
            'Write(./production/**)'
          ],
          'deny' => [
            'Bash(rm -rf:*)',
            'Bash(shred:*)',
            'Read(./.env)',
            'Read(./.env.*)',
            'Read(./secrets/**)',
            'Read(./**/*.key)',
            'Write(./**/.env*)',
            'Write(./**/*.key)'
          ]
        }
      }
    end

    def claude_settings_config(manifest)
      deep_merge(base_claude_settings_config, manifest['native_config_overlay'] || {})
    end

    def base_opencode_config
      {
        '$schema' => 'https://opencode.ai/config.json',
        'instructions' => [
          'AGENTS.md',
          '.vibe/opencode/behavior-policies.md',
          '.vibe/opencode/safety.md',
          '.vibe/opencode/task-routing.md',
          '.vibe/opencode/test-standards.md'
        ],
        'permission' => {
          'read' => {
            '*' => 'allow',
            '**/.env' => 'deny',
            '**/.env.*' => 'deny',
            '**/secrets/**' => 'deny',
            '**/*.key' => 'deny'
          },
          'write' => {
            '*' => 'ask',
            '**/.env*' => 'deny',
            '**/secrets/**' => 'deny',
            '**/*.key' => 'deny'
          },
          'edit' => {
            '*' => 'ask',
            '**/.env*' => 'deny',
            '**/secrets/**' => 'deny',
            '**/*.key' => 'deny'
          },
          'list' => 'allow',
          'glob' => 'allow',
          'grep' => 'allow',
          'todoread' => 'allow',
          'todowrite' => 'allow',
          'bash' => {
            '*' => 'ask',
            'pwd' => 'allow',
            'ls*' => 'allow',
            'cat *' => 'allow',
            'grep *' => 'allow',
            'rg *' => 'allow',
            'find *' => 'allow',
            'git status*' => 'allow',
            'git diff*' => 'allow',
            'git log*' => 'allow',
            'rm *' => 'deny',
            'shred *' => 'deny',
            'curl *' => 'ask',
            'wget *' => 'ask',
            'scp *' => 'ask',
            'rsync *' => 'ask',
            'git push *' => 'ask',
            'npm publish *' => 'ask'
          },
          'webfetch' => 'ask',
          'websearch' => 'ask',
          'task' => 'ask',
          'skill' => 'ask',
          'external_directory' => 'deny'
        }
      }
    end

    def opencode_config(manifest)
      deep_merge(base_opencode_config, manifest['native_config_overlay'] || {})
    end

    def opencode_project_config(manifest)
      # Project-level minimal config - aligned with Claude Code structure
      # Note: OpenCode does NOT support 'extends' - it auto-merges configs by precedence
      # Project config (~/.config/opencode/opencode.json) is loaded after global config
      # So we only include project-specific overrides here
      base = {
        '$schema' => 'https://opencode.ai/config.json',
        'instructions' => [
          'AGENTS.md',
          '.vibe/opencode/behavior-policies.md',
          '.vibe/opencode/safety.md'
        ]
      }
      deep_merge(base, manifest['native_config_overlay'] || {})
    end
  end
end
