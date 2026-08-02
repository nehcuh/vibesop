#!/bin/bash
#
# vibe-bash.sh - Pure Bash fallback for Windows (Git Bash/MSYS2) environments
# Usage: ./vibe-bash.sh [command] [options]
#
# This script provides core functionality when Ruby is not available.
# It works with pre-generated configurations in the generated/ directory.

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="1.0.0-bash"

# Colors (disable if not terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Get user home directory (cross-platform)
get_home_dir() {
    if [ -n "$USERPROFILE" ]; then
        # Windows/Git Bash
        echo "$USERPROFILE" | sed 's/\\/\//g' | sed 's/^C:/\/c/'
    else
        echo "$HOME"
    fi
}

# Show usage
show_help() {
    cat << 'EOF'
Usage: vibe-bash.sh <command> [options]

Pure Bash fallback for Windows (Git Bash/MSYS2) environments.
Works with pre-generated configurations.

Commands:
  build <target> [output-dir]   Build target configuration
  switch <target>               Apply configuration to current directory
  apply <target>                Alias for switch
  targets                       List available targets
  doctor                        Check environment
  help                          Show this help message

Supported Targets:
  claude-code                   Claude Code configuration
  opencode                      OpenCode configuration

Examples:
  ./vibe-bash.sh build opencode
  ./vibe-bash.sh switch opencode
  ./vibe-bash.sh targets

Note: This is a simplified fallback version. For full functionality,
      please install Ruby and use the main 'vibe' command.
EOF
}

# Build command - copy pre-generated configs
cmd_build() {
    local target="$1"
    local output_dir="${2:-generated/$target}"
    
    if [ -z "$target" ]; then
        log_error "Target is required"
        echo "Usage: vibe-bash.sh build <target> [output-dir]"
        echo "Run 'vibe-bash.sh targets' for available targets"
        return 1
    fi
    
    # Validate target
    if [ ! -d "$REPO_ROOT/generated/$target" ]; then
        log_error "Target '$target' not found"
        log_info "Available targets:"
        cmd_targets
        return 1
    fi
    
    log_info "Building target: $target"
    log_info "Output directory: $output_dir"
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Copy pre-generated files
    if [ -d "$REPO_ROOT/generated/$target/.vibe" ]; then
        cp -r "$REPO_ROOT/generated/$target/.vibe" "$output_dir/"
        log_success "Copied .vibe/ directory"
    fi
    
    if [ -f "$REPO_ROOT/generated/$target/AGENTS.md" ]; then
        cp "$REPO_ROOT/generated/$target/AGENTS.md" "$output_dir/"
        log_success "Copied AGENTS.md"
    fi
    
    if [ -f "$REPO_ROOT/generated/$target/opencode.json" ]; then
        cp "$REPO_ROOT/generated/$target/opencode.json" "$output_dir/"
        log_success "Copied opencode.json"
    fi
    
    if [ -f "$REPO_ROOT/generated/$target/CLAUDE.md" ]; then
        cp "$REPO_ROOT/generated/$target/CLAUDE.md" "$output_dir/"
        log_success "Copied CLAUDE.md"
    fi
    
    if [ -f "$REPO_ROOT/generated/$target/settings.json" ]; then
        cp "$REPO_ROOT/generated/$target/settings.json" "$output_dir/"
        log_success "Copied settings.json"
    fi
    
    log_success "Build complete: $output_dir"
    echo ""
    log_info "Next steps:"
    echo "  1. Review files in $output_dir"
    echo "  2. Run: ./vibe-bash.sh switch $target"
}

# Switch/Apply command - apply to current directory
cmd_switch() {
    local target="$1"
    
    if [ -z "$target" ]; then
        log_error "Target is required"
        echo "Usage: vibe-bash.sh switch <target>"
        return 1
    fi
    
    # Get current directory
    local project_dir="$(pwd)"
    
    log_info "Applying $target configuration to: $project_dir"
    
    # Check if generated config exists
    if [ ! -d "$REPO_ROOT/generated/$target" ]; then
        log_error "Target '$target' not found in generated/"
        log_info "Run first: ./vibe-bash.sh build $target"
        return 1
    fi
    
    # Copy main config files to project root
    local copied=0
    
    if [ -f "$REPO_ROOT/generated/$target/AGENTS.md" ]; then
        cp "$REPO_ROOT/generated/$target/AGENTS.md" "$project_dir/"
        log_success "Applied AGENTS.md"
        ((copied++))
    fi
    
    if [ -f "$REPO_ROOT/generated/$target/opencode.json" ]; then
        cp "$REPO_ROOT/generated/$target/opencode.json" "$project_dir/"
        log_success "Applied opencode.json"
        ((copied++))
    fi
    
    if [ -f "$REPO_ROOT/generated/$target/CLAUDE.md" ]; then
        cp "$REPO_ROOT/generated/$target/CLAUDE.md" "$project_dir/"
        log_success "Applied CLAUDE.md"
        ((copied++))
    fi
    
    # Create .vibe directory if needed
    if [ -d "$REPO_ROOT/generated/$target/.vibe" ]; then
        mkdir -p "$project_dir/.vibe"
        cp -r "$REPO_ROOT/generated/$target/.vibe/"* "$project_dir/.vibe/"
        log_success "Applied .vibe/ directory"
        ((copied++))
    fi
    
    if [ $copied -eq 0 ]; then
        log_warn "No configuration files found for $target"
        return 1
    fi
    
    # Create marker file
    echo "{\"target\": \"$target\", \"version\": \"$VERSION\"}" > "$project_dir/.vibe-target.json"
    log_success "Created .vibe-target.json marker"
    
    echo ""
    log_success "Configuration applied successfully!"
    echo ""
    log_info "Your project now has:"
    ls -la "$project_dir"/AGENTS.md "$project_dir"/.vibe/ 2>/dev/null || true
}

# Alias for switch
cmd_apply() {
    cmd_switch "$@"
}

# List available targets
cmd_targets() {
    log_info "Available targets:"
    echo ""
    
    if [ -d "$REPO_ROOT/generated" ]; then
        for target_dir in "$REPO_ROOT/generated"/*/; do
            if [ -d "$target_dir" ]; then
                local target=$(basename "$target_dir")
                local status="✓"
                
                # Check for main config files
                if [ -f "$target_dir/AGENTS.md" ] || [ -f "$target_dir/CLAUDE.md" ]; then
                    echo "  $status $target"
                fi
            fi
        done
    else
        log_warn "No generated/ directory found"
        echo "  Run 'make generate' or use the Ruby version first"
    fi
    
    echo ""
    log_info "Usage:"
    echo "  ./vibe-bash.sh build <target>"
    echo "  ./vibe-bash.sh switch <target>"
}

# Doctor command - check environment
cmd_doctor() {
    log_info "Environment Check (Bash Fallback Mode)"
    echo "====================================="
    echo ""
    
    # Check shell
    log_info "Shell: $SHELL"
    log_info "Bash version: $BASH_VERSION"
    
    # Check Git
    if command -v git &> /dev/null; then
        log_success "Git: $(git --version | head -1)"
    else
        log_error "Git: not found"
    fi
    
    # Check for Ruby (optional)
    if command -v ruby &> /dev/null; then
        log_success "Ruby: $(ruby --version)"
        log_warn "Ruby is available! Consider using the full 'vibe' command"
    else
        log_info "Ruby: not found (using bash fallback)"
    fi
    
    # Check repo structure
    echo ""
    log_info "Repository structure:"
    if [ -d "$REPO_ROOT/generated" ]; then
        local count=$(find "$REPO_ROOT/generated" -maxdepth 1 -type d | wc -l)
        log_success "generated/: found ($((count-1)) targets)"
    else
        log_error "generated/: not found"
    fi
    
    if [ -d "$REPO_ROOT/core" ]; then
        log_success "core/: found"
    else
        log_error "core/: not found"
    fi
    
    # Check write permissions
    echo ""
    log_info "Permissions:"
    if [ -w "$REPO_ROOT" ]; then
        log_success "Repository directory: writable"
    else
        log_error "Repository directory: not writable"
    fi
    
    if [ -w "$(pwd)" ]; then
        log_success "Current directory: writable"
    else
        log_error "Current directory: not writable"
    fi
    
    echo ""
    log_info "Status: Bash fallback mode ready"
    log_info "Version: $VERSION"
}

# Main command dispatcher
main() {
    local command="$1"
    
    # Handle version flag
    if [ "$command" = "--version" ] || [ "$command" = "-v" ]; then
        echo "vibe-bash $VERSION (fallback for Windows/Git Bash)"
        echo "Repository: $REPO_ROOT"
        return 0
    fi
    
    # Handle help
    if [ -z "$command" ] || [ "$command" = "help" ] || [ "$command" = "--help" ] || [ "$command" = "-h" ]; then
        show_help
        return 0
    fi
    
    # Dispatch to command handlers
    shift || true
    case "$command" in
        build)
            cmd_build "$@"
            ;;
        switch|apply)
            cmd_switch "$@"
            ;;
        targets)
            cmd_targets
            ;;
        doctor)
            cmd_doctor
            ;;
        use|deploy|init|quickstart|inspect|skills)
            log_error "Command '$command' is not supported in bash fallback mode"
            log_info "This command requires Ruby and the full 'vibe' CLI"
            log_info "Please install Ruby or use an alternative approach"
            return 1
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            return 1
            ;;
    esac
}

# Run main
main "$@"
