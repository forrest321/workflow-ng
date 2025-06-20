#!/usr/bin/env bash
# Claude CLAUDE.md Integration Helper
# Safely integrates workflow framework content with existing CLAUDE.md files

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[CLAUDE-MD]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

# Check if project has existing CLAUDE.md
check_existing_claude_md() {
    local target_dir="$1"
    local claude_md_path="$target_dir/CLAUDE.md"
    
    if [[ -f "$claude_md_path" ]]; then
        echo "existing"
    else
        echo "none"
    fi
}

# Create framework content section
create_framework_section() {
    cat << 'EOF'

# Claude Workflow Framework Integration

This project has been enhanced with the Claude Workflow Framework for improved coordination between multiple Claude Code instances.

## Framework Features

- **Enhanced Redis-based coordination** with real-time work distribution
- **Expert Knowledge Base integration** with 85,000+ expert knowledge chunks across 73 domains
- **Automatic work recovery** with orphaned task detection and cleanup
- **Redis-enhanced file building** with atomic operations and locks
- **Service dependency management** with auto-start detection
- **User-controlled fallback** to file-based coordination when needed

## Quick Start

To activate the workflow framework in this project:

```bash
# Activate framework utilities
source .claude/scripts/activate.sh

# Check system status
claude-status

# Start enhanced coordination (optional but recommended)
claude-coordinator start-with-fallback

# Or start Redis coordination manually
docker-compose -f docker-compose.coordination.yml up -d
```

## Available Commands

After activation, these commands are available:

### Basic Coordination
- `claude-claim <task>` - Claim a task exclusively
- `claude-release <task>` - Release a claimed task
- `claude-list` - List your active tasks
- `claude-cleanup` - Clean up expired claims
- `claude-status` - Show coordination status

### Enhanced Coordination
- `claude-coordinator` - Workflow coordination daemon
- `claude-services` - Service management
- `claude-recovery` - Work recovery system

### Expert Knowledge Base
- `claude-coordinator query-expert "query" [domain]` - Query Expert Knowledge Base
- `claude-coordinator get-guidance <task-type> [tech]` - Get coordination guidance
- `claude-coordinator get-practices <technology>` - Get best practices

## Expert System Integration

The framework includes access to specialized expert domains:
- **Programming Languages**: JavaScript, Go, Python, Rust, Java, etc.
- **Frameworks**: React, Flutter, Rails, Spring Boot, etc.
- **Infrastructure**: Docker, Kubernetes, Terraform, Ansible
- **Databases**: PostgreSQL, MySQL, Redis, Firebase
- **Development Tools**: Git, CI/CD, Testing frameworks

For detailed guidance:
```bash
# Get project planning guidance
.claude/scripts/expert-enhanced-planner.sh plan "your project description"

# Get implementation guidance
.claude/scripts/expert-guided-implementation.sh guide "feature" "technology"

# Get testing strategy
.claude/scripts/expert-testing-deployment.sh test-plan "project" "tech stack"
```

## Configuration

Framework configuration is stored in `.claude/config/workflow.{json,yml}` and includes:
- Coordination mode (Redis or file-based)
- Task definitions and quality gates
- Agent settings and specializations
- Expert system integration settings

## Documentation

Complete framework documentation is available in:
- `.claude/README.md` - Comprehensive usage guide
- `.claude/CLAUDE.md` - Framework CLAUDE.md content
- `.claude/docs/expert-system-integration.md` - Expert system guide
- `.claude/rules/workflow-governance.md` - Workflow rules
- `.claude/concurrency/claude-coordination.md` - Coordination patterns

## Environment Variables

```bash
# Expert Knowledge Base configuration
export EXPERT_SYSTEM_URL="http://localhost:8080"
export EXPERT_SYSTEM_ENABLED="true"

# Redis coordination configuration
export REDIS_URL="redis://localhost:6379"
export RECOVERY_INTERVAL="300"
```

For troubleshooting and advanced usage, see `.claude/README.md`.

EOF
}

# Backup existing CLAUDE.md
backup_claude_md() {
    local target_dir="$1"
    local claude_md_path="$target_dir/CLAUDE.md"
    local backup_path="$target_dir/CLAUDE.md.backup.$(date +%Y%m%d-%H%M%S)"
    
    if [[ -f "$claude_md_path" ]]; then
        cp "$claude_md_path" "$backup_path"
        log "Created backup: $backup_path"
        echo "$backup_path"
    fi
}

# Integrate framework content with existing CLAUDE.md
integrate_framework_content() {
    local target_dir="$1"
    local mode="${2:-append}"
    local claude_md_path="$target_dir/CLAUDE.md"
    
    case "$mode" in
        "append")
            log "Appending framework content to existing CLAUDE.md"
            create_framework_section >> "$claude_md_path"
            ;;
        "prepend")
            log "Prepending framework content to existing CLAUDE.md"
            local temp_file=$(mktemp)
            create_framework_section > "$temp_file"
            echo "" >> "$temp_file"
            cat "$claude_md_path" >> "$temp_file"
            mv "$temp_file" "$claude_md_path"
            ;;
        "replace")
            warn "Replacing existing CLAUDE.md with framework content"
            create_framework_section > "$claude_md_path"
            ;;
        "skip")
            info "Skipping CLAUDE.md integration"
            return 0
            ;;
    esac
    
    log "Framework content integrated into CLAUDE.md"
}

# Create standalone framework CLAUDE.md
create_framework_claude_md() {
    local target_dir="$1"
    local claude_md_path="$target_dir/CLAUDE.md"
    
    log "Creating new CLAUDE.md with framework content"
    create_framework_section > "$claude_md_path"
}

# Interactive integration
interactive_integration() {
    local target_dir="$1"
    local existing_status
    existing_status=$(check_existing_claude_md "$target_dir")
    
    if [[ "$existing_status" == "existing" ]]; then
        echo ""
        warn "Existing CLAUDE.md file detected!"
        warn "The workflow framework needs to add content to CLAUDE.md for proper integration."
        echo ""
        echo "Options:"
        echo "1) Append framework content to existing CLAUDE.md (recommended)"
        echo "2) Prepend framework content to existing CLAUDE.md"
        echo "3) Skip CLAUDE.md integration (framework will work but be less discoverable)"
        echo "4) View existing CLAUDE.md content first"
        echo "5) Cancel installation"
        echo ""
        
        while true; do
            read -p "Choose option [1-5]: " -n 1 -r choice
            echo ""
            
            case "$choice" in
                1)
                    backup_claude_md "$target_dir"
                    integrate_framework_content "$target_dir" "append"
                    break
                    ;;
                2)
                    backup_claude_md "$target_dir"
                    integrate_framework_content "$target_dir" "prepend"
                    break
                    ;;
                3)
                    integrate_framework_content "$target_dir" "skip"
                    warn "Framework installed without CLAUDE.md integration"
                    warn "See .claude/README.md and .claude/CLAUDE.md for usage information"
                    break
                    ;;
                4)
                    echo ""
                    echo "=== Current CLAUDE.md content ==="
                    head -n 50 "$target_dir/CLAUDE.md"
                    echo ""
                    echo "=== (showing first 50 lines) ==="
                    echo ""
                    ;;
                5)
                    error "Installation cancelled by user"
                    return 1
                    ;;
                *)
                    echo "Invalid choice. Please select 1-5."
                    ;;
            esac
        done
    else
        log "No existing CLAUDE.md found - creating new one"
        create_framework_claude_md "$target_dir"
    fi
    
    return 0
}

# Non-interactive integration (for automated installs)
non_interactive_integration() {
    local target_dir="$1"
    local mode="${2:-safe}"
    local existing_status
    existing_status=$(check_existing_claude_md "$target_dir")
    
    if [[ "$existing_status" == "existing" ]]; then
        case "$mode" in
            "safe")
                # Safe mode: don't modify existing CLAUDE.md
                warn "Existing CLAUDE.md detected - skipping integration to avoid overwriting"
                warn "Framework is installed but CLAUDE.md integration was skipped"
                warn "To manually integrate, run: $0 integrate \"$target_dir\""
                warn "Framework documentation is available in .claude/README.md"
                ;;
            "append")
                backup_claude_md "$target_dir"
                integrate_framework_content "$target_dir" "append"
                ;;
            "prepend")
                backup_claude_md "$target_dir"
                integrate_framework_content "$target_dir" "prepend"
                ;;
            "skip")
                integrate_framework_content "$target_dir" "skip"
                ;;
            *)
                error "Unknown non-interactive mode: $mode"
                return 1
                ;;
        esac
    else
        create_framework_claude_md "$target_dir"
    fi
    
    return 0
}

# Main interface
main() {
    case "${1:-help}" in
        "check")
            local target_dir="${2:-$(pwd)}"
            local status
            status=$(check_existing_claude_md "$target_dir")
            echo "CLAUDE.md status in $target_dir: $status"
            ;;
        "integrate")
            local target_dir="${2:-$(pwd)}"
            interactive_integration "$target_dir"
            ;;
        "auto")
            local target_dir="${2:-$(pwd)}"
            local mode="${3:-safe}"
            non_interactive_integration "$target_dir" "$mode"
            ;;
        "backup")
            local target_dir="${2:-$(pwd)}"
            backup_claude_md "$target_dir"
            ;;
        "create")
            local target_dir="${2:-$(pwd)}"
            create_framework_claude_md "$target_dir"
            ;;
        "help"|"-h"|"--help")
            echo "Claude CLAUDE.md Integration Helper"
            echo "=================================="
            echo ""
            echo "Usage: $0 [command] [target-directory] [options]"
            echo ""
            echo "Commands:"
            echo "  check [dir]                   Check CLAUDE.md status"
            echo "  integrate [dir]               Interactive integration"
            echo "  auto [dir] [mode]             Non-interactive integration"
            echo "  backup [dir]                  Backup existing CLAUDE.md"
            echo "  create [dir]                  Create new framework CLAUDE.md"
            echo "  help                          Show this help"
            echo ""
            echo "Auto modes:"
            echo "  safe                          Don't modify existing CLAUDE.md (default)"
            echo "  append                        Append framework content"
            echo "  prepend                       Prepend framework content"
            echo "  skip                          Skip CLAUDE.md integration"
            echo ""
            echo "Examples:"
            echo "  $0 check                      # Check current directory"
            echo "  $0 integrate /path/to/project # Interactive integration"
            echo "  $0 auto . append              # Auto-append to current directory"
            echo "  $0 backup                     # Backup existing CLAUDE.md"
            exit 0
            ;;
        *)
            error "Unknown command: $1"
            error "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi