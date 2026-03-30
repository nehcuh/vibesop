#!/bin/bash
# Pre-Tool-Use Auto-Route Hook
# Automatically calls 'vibe route' before Claude executes major tools
# This ensures proper skill discovery and loading

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the tool name from environment (Claude Code provides this)
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# Only route for certain tools that indicate the start of a new task
# Tools that trigger routing:
ROUTABLE_TOOLS=(
    "Bash"
    "Edit"
    "Write"
    "Agent"
)

# Check if this tool should trigger routing
should_route() {
    local tool="$1"

    # Skip for read-only tools (no routing needed for inspection)
    if [[ "$tool" == "Read" ]] || [[ "$tool" == "Glob" ]] || [[ "$tool" == "Grep" ]]; then
        return 1
    fi

    # Check if tool is in our routable list
    for rt in "${ROUTABLE_TOOLS[@]}"; do
        if [[ "$tool" == "$rt" ]]; then
            return 0
        fi
    done

    return 1
}

# Check if we've already routed for this session
already_routed() {
    [[ -f "/tmp/vibe_auto_routed_$$" ]]
}

mark_routed() {
    touch "/tmp/vibe_auto_routed_$$"
}

# Main logic
if should_route "$TOOL_NAME"; then
    # Only route once per session to avoid spam
    if already_routed; then
        exit 0
    fi

    # Check if vibe is available
    if ! command -v vibe &> /dev/null; then
        exit 0
    fi

    # Check if we're in a project with vibe config
    if [[ ! -f ".vibe/skill-routing.yaml" ]] && [[ ! -f "core/skills/registry.yaml" ]]; then
        exit 0
    fi

    # Extract user intent from tool input (simplified)
    # For Bash tools with "help me" or "帮我" or similar
    USER_INTENT=""

    if [[ -n "$TOOL_INPUT" ]]; then
        # Look for intent keywords in the input
        if echo "$TOOL_INPUT" | grep -qiE "(help|帮我|协助|审查|review|debug|调试|refactor|重构|test|测试|deploy|部署)"; then
            USER_INTENT="$TOOL_INPUT"
        fi
    fi

    # Only auto-route if we detected intent
    if [[ -n "$USER_INTENT" ]]; then
        echo -e "${BLUE}🔍 Auto-routing detected intent...${NC}" >&2

        # Call vibe route and capture output
        ROUTE_OUTPUT=$(vibe route "$USER_INTENT" 2>&1 || true)

        # If route found a skill, display it prominently
        if echo "$ROUTE_OUTPUT" | grep -q "匹配到技能"; then
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
            echo -e "${GREEN}🎯 Recommended Skill Detected${NC}" >&2
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
            echo "" >&2
            echo "$ROUTE_OUTPUT" >&2
            echo "" >&2
            echo -e "${BLUE}💡 Claude will now load the recommended skill.${NC}" >&2
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
            echo "" >&2

            mark_routed
        fi
    fi
fi

exit 0
