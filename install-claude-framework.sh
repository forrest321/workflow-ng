#!/usr/bin/env bash
# Claude Workflow Framework - Foolproof Installation Script
# Supports both macOS and Linux, with full error handling and verification

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$(pwd)}"
INSTALL_LOG="${TARGET_DIR}/.claude-install.log"
ROLLBACK_MANIFEST="${TARGET_DIR}/.claude-rollback.manifest"

# Initialize log
echo "Claude Framework Installation - $(date)" > "$INSTALL_LOG"

# Helper functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*" | tee -a "$INSTALL_LOG"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$INSTALL_LOG" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$INSTALL_LOG"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$INSTALL_LOG"
}

# Track installed files for rollback
track_file() {
    echo "$1" >> "$ROLLBACK_MANIFEST"
}

# Rollback function
rollback() {
    error "Installation failed. Rolling back changes..."
    if [[ -f "$ROLLBACK_MANIFEST" ]]; then
        while IFS= read -r file; do
            if [[ -e "$file" ]]; then
                rm -rf "$file"
                log "Removed: $file"
            fi
        done < "$ROLLBACK_MANIFEST"
        rm -f "$ROLLBACK_MANIFEST"
    fi
    rm -f "$INSTALL_LOG"
    exit 1
}

# Set trap for rollback on error
trap rollback ERR

# Platform detection
detect_platform() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*) echo "linux" ;;
        *) echo "unknown" ;;
    esac
}

PLATFORM=$(detect_platform)
log "Detected platform: $PLATFORM"

# Get ISO date based on platform
get_iso_date() {
    if [[ "$PLATFORM" == "macos" ]]; then
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    else
        date -u --iso-8601=seconds | sed 's/+00:00/Z/'
    fi
}

# Get date with offset based on platform
get_date_with_offset() {
    local offset_seconds=$1
    if [[ "$PLATFORM" == "macos" ]]; then
        date -u -v+${offset_seconds}S +"%Y-%m-%dT%H:%M:%SZ"
    else
        date -u -d "+${offset_seconds} seconds" +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# Verify source directory
verify_source() {
    local required_files=(
        "CLAUDE.md"
        "README.md"
        "CLAUDE_COORDINATION_PLAN.md"
        "IMPLEMENTATION_GUIDE.md"
    )
    
    local required_dirs=(
        "concurrency"
        "docs"
        "rules"
        "tasks"
        "terminology"
    )
    
    # Check for enhanced scripts directory (optional but recommended)
    if [[ -d "$SCRIPT_DIR/scripts" ]]; then
        required_dirs+=("scripts")
        info "Enhanced coordination scripts found - will be installed"
    else
        warn "Enhanced coordination scripts not found - using basic coordination only"
    fi
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            error "Missing required file: $file"
            error "Are you running this script from the workflow-ng directory?"
            return 1
        fi
    done
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$SCRIPT_DIR/$dir" ]]; then
            error "Missing required directory: $dir"
            return 1
        fi
    done
    
    return 0
}

# Create directory with tracking
create_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        track_file "$dir"
        log "Created directory: $dir"
    fi
}

# Copy file with tracking and verification
copy_file() {
    local src="$1"
    local dest="$2"
    local desc="${3:-$src}"
    
    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        track_file "$dest"
        log "✓ Copied $desc"
        return 0
    else
        warn "⚠ Source not found: $src"
        return 1
    fi
}

# Copy directory recursively with tracking
copy_dir() {
    local src="$1"
    local dest="$2"
    local desc="${3:-$src}"
    
    if [[ -d "$src" ]]; then
        cp -r "$src" "$dest"
        track_file "$dest"
        log "✓ Copied directory: $desc"
        
        # Track all files in the directory
        find "$dest" -type f | while read -r file; do
            track_file "$file"
        done
        return 0
    else
        warn "⚠ Source directory not found: $src"
        return 1
    fi
}

# Detect project type
detect_project_type() {
    if [[ -f "$TARGET_DIR/package.json" ]]; then
        echo "node"
    elif [[ -f "$TARGET_DIR/requirements.txt" ]] || [[ -f "$TARGET_DIR/pyproject.toml" ]]; then
        echo "python"
    elif [[ -f "$TARGET_DIR/go.mod" ]]; then
        echo "go"
    elif [[ -f "$TARGET_DIR/Cargo.toml" ]]; then
        echo "rust"
    else
        echo "generic"
    fi
}

# Main installation
main() {
    echo ""
    info "=== Claude Workflow Framework Installation ==="
    info "Version: 2.0 (Foolproof Edition)"
    info "Target: $TARGET_DIR"
    echo ""
    
    # Validate target directory
    if [[ ! -d "$TARGET_DIR" ]]; then
        error "Target directory does not exist: $TARGET_DIR"
        exit 1
    fi
    
    # Verify source files
    log "Verifying source files..."
    if ! verify_source; then
        error "Source verification failed"
        exit 1
    fi
    
    # Initialize rollback manifest
    > "$ROLLBACK_MANIFEST"
    
    # Detect project type
    PROJECT_TYPE=$(detect_project_type)
    log "Detected project type: $PROJECT_TYPE"
    
    # Create .claude directory structure
    log "Creating directory structure..."
    create_dir "$TARGET_DIR/.claude"
    create_dir "$TARGET_DIR/.claude/config"
    create_dir "$TARGET_DIR/.claude/coordination"
    create_dir "$TARGET_DIR/.claude/coordination/tasks"
    create_dir "$TARGET_DIR/.claude/coordination/claims"
    create_dir "$TARGET_DIR/.claude/coordination/agents"
    create_dir "$TARGET_DIR/.claude/coordination/status"
    create_dir "$TARGET_DIR/.claude/coordination/logs"
    create_dir "$TARGET_DIR/.claude/scripts"
    create_dir "$TARGET_DIR/.claude/templates"
    create_dir "$TARGET_DIR/.claude/metrics"
    create_dir "$TARGET_DIR/.claude/logs"
    create_dir "$TARGET_DIR/.claude/docs"
    create_dir "$TARGET_DIR/.claude/rules"
    create_dir "$TARGET_DIR/.claude/terminology"
    create_dir "$TARGET_DIR/.claude/api"
    
    # Copy essential files to .claude directory (DO NOT overwrite project root CLAUDE.md)
    log "Installing framework files..."
    copy_file "$SCRIPT_DIR/CLAUDE.md" "$TARGET_DIR/.claude/CLAUDE.md" "CLAUDE.md (to .claude directory)"
    copy_file "$SCRIPT_DIR/CLAUDE_COORDINATION_PLAN.md" "$TARGET_DIR/.claude/CLAUDE_COORDINATION_PLAN.md" "Coordination Plan"
    copy_file "$SCRIPT_DIR/IMPLEMENTATION_GUIDE.md" "$TARGET_DIR/.claude/IMPLEMENTATION_GUIDE.md" "Implementation Guide"
    
    # Safe CLAUDE.md integration
    log "Handling CLAUDE.md integration..."
    if [[ -f "$SCRIPT_DIR/scripts/claude-md-integration.sh" ]]; then
        "$SCRIPT_DIR/scripts/claude-md-integration.sh" auto "$TARGET_DIR" safe
    else
        warn "CLAUDE.md integration script not found - skipping root CLAUDE.md modification"
        warn "Framework documentation available in .claude/README.md"
    fi
    
    # Copy directories
    log "Installing framework directories..."
    copy_dir "$SCRIPT_DIR/docs" "$TARGET_DIR/.claude/docs" "Documentation"
    copy_dir "$SCRIPT_DIR/rules" "$TARGET_DIR/.claude/rules" "Rules"
    copy_dir "$SCRIPT_DIR/terminology" "$TARGET_DIR/.claude/terminology" "Terminology"
    copy_dir "$SCRIPT_DIR/tasks" "$TARGET_DIR/.claude/tasks" "Tasks"
    copy_dir "$SCRIPT_DIR/concurrency" "$TARGET_DIR/.claude/concurrency" "Concurrency Guidelines"
    
    # Copy enhanced coordination scripts
    if [[ -d "$SCRIPT_DIR/scripts" ]]; then
        log "Installing enhanced coordination scripts..."
        copy_file "$SCRIPT_DIR/scripts/service-manager.sh" "$TARGET_DIR/.claude/scripts/service-manager.sh" "Service Manager"
        copy_file "$SCRIPT_DIR/scripts/work-recovery.sh" "$TARGET_DIR/.claude/scripts/work-recovery.sh" "Work Recovery System"
        copy_file "$SCRIPT_DIR/scripts/workflow-coordinator.sh" "$TARGET_DIR/.claude/scripts/workflow-coordinator.sh" "Workflow Coordinator"
        copy_file "$SCRIPT_DIR/scripts/redis-file-builder.sh" "$TARGET_DIR/.claude/scripts/redis-file-builder.sh" "Redis File Builder"
        copy_file "$SCRIPT_DIR/scripts/workflow-file-ops.sh" "$TARGET_DIR/.claude/scripts/workflow-file-ops.sh" "Workflow File Operations"
        copy_file "$SCRIPT_DIR/scripts/expert-enhanced-planner.sh" "$TARGET_DIR/.claude/scripts/expert-enhanced-planner.sh" "Expert-Enhanced Planner"
        copy_file "$SCRIPT_DIR/scripts/expert-guided-implementation.sh" "$TARGET_DIR/.claude/scripts/expert-guided-implementation.sh" "Expert-Guided Implementation"
        copy_file "$SCRIPT_DIR/scripts/expert-testing-deployment.sh" "$TARGET_DIR/.claude/scripts/expert-testing-deployment.sh" "Expert Testing & Deployment"
        copy_file "$SCRIPT_DIR/scripts/claude-md-integration.sh" "$TARGET_DIR/.claude/scripts/claude-md-integration.sh" "CLAUDE.md Integration Helper"
        
        # Make scripts executable
        chmod +x "$TARGET_DIR/.claude/scripts"/*.sh
    fi
    
    # Copy optional directories if they exist
    if [[ -d "$SCRIPT_DIR/api" ]]; then
        copy_dir "$SCRIPT_DIR/api" "$TARGET_DIR/.claude/api" "API Patterns"
    fi
    
    if [[ -d "$SCRIPT_DIR/daggerio" ]]; then
        copy_dir "$SCRIPT_DIR/daggerio" "$TARGET_DIR/.claude/daggerio" "Dagger.io Patterns"
    fi
    
    if [[ -d "$SCRIPT_DIR/ops" ]]; then
        copy_dir "$SCRIPT_DIR/ops" "$TARGET_DIR/.claude/ops" "Operations"
    fi
    
    if [[ -d "$SCRIPT_DIR/tui" ]]; then
        copy_dir "$SCRIPT_DIR/tui" "$TARGET_DIR/.claude/tui" "TUI Guidelines"
    fi
    
    if [[ -d "$SCRIPT_DIR/web" ]]; then
        copy_dir "$SCRIPT_DIR/web" "$TARGET_DIR/.claude/web" "Web Integration"
    fi
    
    # Generate agent ID
    AGENT_ID="claude-$(hostname)-$(date +%s)"
    echo "$AGENT_ID" > "$TARGET_DIR/.claude/agent_id"
    track_file "$TARGET_DIR/.claude/agent_id"
    log "Generated agent ID: $AGENT_ID"
    
    # Create project-specific configuration
    log "Creating project configuration..."
    create_project_config
    
    # Create coordination scripts
    log "Installing coordination scripts..."
    create_coordination_scripts
    
    # Create Docker compose file
    log "Creating Docker compose configuration..."
    create_docker_compose
    
    # Create README
    log "Creating README..."
    create_readme
    
    # Verification
    log "Verifying installation..."
    if verify_installation; then
        log "✓ Installation verified successfully"
        
        # Clean up rollback manifest on success
        rm -f "$ROLLBACK_MANIFEST"
        
        echo ""
        info "=== Installation Complete! ==="
        info "Agent ID: $AGENT_ID"
        info "Project Type: $PROJECT_TYPE"
        echo ""
        success "🔒 CLAUDE.md Protection: Existing CLAUDE.md files are preserved!"
        info "   - Framework content stored in .claude/CLAUDE.md"  
        info "   - Project root CLAUDE.md left untouched for /init compatibility"
        echo ""
        info "Next steps:"
        info "1. cd $TARGET_DIR"
        info "2. source .claude/scripts/activate.sh"
        info "3. claude-status"
        echo ""
        info "For enhanced coordination with Expert system (recommended):"
        info "4. claude-coordinator start-with-fallback"
        echo ""
        info "Or manual Redis coordination:"
        info "4. docker-compose -f docker-compose.coordination.yml up -d"
        echo ""
        info "Enhanced commands available after activation:"
        info "  claude-coordinator - Workflow coordination daemon with Expert integration"
        info "  claude-services    - Service management"
        info "  claude-recovery    - Work recovery system"
        echo ""
        info "Expert Knowledge Base commands:"
        info "  .claude/scripts/expert-enhanced-planner.sh - AI-powered project planning"
        info "  .claude/scripts/expert-guided-implementation.sh - Development assistance"
        info "  .claude/scripts/expert-testing-deployment.sh - Testing and deployment guidance"
        echo ""
        info "To optionally integrate framework content into your CLAUDE.md:"
        info "  .claude/scripts/claude-md-integration.sh integrate"
        echo ""
        info "See .claude/README.md for detailed usage"
        echo ""
    else
        error "Installation verification failed"
        rollback
    fi
}

# Create project-specific configuration
create_project_config() {
    case "$PROJECT_TYPE" in
        "node")
            cat > "$TARGET_DIR/.claude/config/workflow.json" << 'EOF'
{
  "project_type": "node",
  "coordination": {
    "mode": "redis",
    "fallback": "file",
    "redis_url": "redis://localhost:6379",
    "claim_ttl": 300,
    "heartbeat_interval": 30
  },
  "tasks": {
    "test": "npm test",
    "lint": "npm run lint",
    "build": "npm run build",
    "type_check": "npm run type-check",
    "format": "npm run format"
  },
  "quality_gates": {
    "pre_commit": ["lint", "type_check", "test"],
    "pre_merge": ["build", "test"],
    "pre_deploy": ["build", "test", "security_scan"]
  },
  "agents": {
    "max_concurrent_tasks": 3,
    "specializations": ["frontend", "backend", "testing", "documentation", "devops"]
  }
}
EOF
            ;;
        "python")
            cat > "$TARGET_DIR/.claude/config/workflow.yml" << 'EOF'
project_type: python
coordination:
  mode: redis
  fallback: file
  redis_url: redis://localhost:6379
  claim_ttl: 300
  heartbeat_interval: 30

tasks:
  test: pytest
  lint: ruff check .
  format: black .
  type_check: mypy .
  security: bandit -r .

quality_gates:
  pre_commit:
    - lint
    - type_check
    - test
  pre_merge:
    - format
    - test
  pre_deploy:
    - security
    - test

agents:
  max_concurrent_tasks: 3
  specializations:
    - data_processing
    - api_development
    - testing
    - ml_ops
    - documentation
EOF
            ;;
        "go")
            cat > "$TARGET_DIR/.claude/config/workflow.yml" << 'EOF'
project_type: go
coordination:
  mode: redis
  fallback: file
  redis_url: redis://localhost:6379
  claim_ttl: 300
  heartbeat_interval: 30

tasks:
  test: go test ./...
  lint: golangci-lint run
  build: go build ./...
  vet: go vet ./...
  mod_tidy: go mod tidy

quality_gates:
  pre_commit:
    - vet
    - lint
    - test
  pre_merge:
    - mod_tidy
    - build
    - test

agents:
  max_concurrent_tasks: 3
  specializations:
    - backend_development
    - microservices
    - testing
    - performance
    - documentation
EOF
            ;;
        "rust")
            cat > "$TARGET_DIR/.claude/config/workflow.yml" << 'EOF'
project_type: rust
coordination:
  mode: redis
  fallback: file
  redis_url: redis://localhost:6379
  claim_ttl: 300
  heartbeat_interval: 30

tasks:
  test: cargo test
  lint: cargo clippy
  build: cargo build
  format: cargo fmt
  check: cargo check

quality_gates:
  pre_commit:
    - format
    - clippy
    - test
  pre_merge:
    - check
    - test

agents:
  max_concurrent_tasks: 3
  specializations:
    - systems_programming
    - async_programming
    - testing
    - performance
    - documentation
EOF
            ;;
        *)
            cat > "$TARGET_DIR/.claude/config/workflow.yml" << 'EOF'
project_type: generic
coordination:
  mode: file
  fallback: file
  claim_ttl: 300

tasks:
  test: echo "Configure test command"
  lint: echo "Configure lint command"
  build: echo "Configure build command"

quality_gates:
  pre_commit: []
  pre_merge: []

agents:
  max_concurrent_tasks: 3
  specializations:
    - development
    - testing
    - documentation
EOF
            ;;
    esac
    track_file "$TARGET_DIR/.claude/config/workflow.*"
}

# Create coordination scripts
create_coordination_scripts() {
    # Create activation script (compatible with both bash and zsh)
    cat > "$TARGET_DIR/.claude/scripts/activate.sh" << 'EOF'
#!/usr/bin/env bash
# Claude Framework Activation Script
# Compatible with both bash and zsh

# Detect shell
if [ -n "$ZSH_VERSION" ]; then
    CLAUDE_SHELL="zsh"
elif [ -n "$BASH_VERSION" ]; then
    CLAUDE_SHELL="bash"
else
    CLAUDE_SHELL="sh"
fi

# Get the directory containing this script
if [ "$CLAUDE_SHELL" = "zsh" ]; then
    if [[ -n "${(%):-%x}" ]]; then
        # When sourced in zsh
        CLAUDE_DIR="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
    else
        # When executed directly in zsh
        CLAUDE_DIR="${0:A:h}/.."
    fi
else
    CLAUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Load agent ID
if [ -f "$CLAUDE_DIR/agent_id" ]; then
    export CLAUDE_AGENT_ID=$(cat "$CLAUDE_DIR/agent_id")
    export CLAUDE_PROJECT_ROOT="$(dirname "$CLAUDE_DIR")"
fi

# Source utilities based on shell
if [ "$CLAUDE_SHELL" = "zsh" ]; then
    source "$CLAUDE_DIR/scripts/coordination-utils.zsh"
else
    source "$CLAUDE_DIR/scripts/coordination-utils.sh"
fi

echo "Claude Framework activated!"
echo "  Shell: $CLAUDE_SHELL"
echo "  Agent ID: $CLAUDE_AGENT_ID"
echo "  Project Root: $CLAUDE_PROJECT_ROOT"
echo ""
echo "Available commands:"
echo "  claude-status          - Show coordination status"
echo "  claude-claim <task>    - Claim a task"
echo "  claude-release <task>  - Release a task"
echo "  claude-list            - List your tasks"
echo "  claude-cleanup         - Clean expired claims"
echo ""
echo "Enhanced coordination commands:"
echo "  claude-coordinator     - Start workflow coordinator"
echo "  claude-services        - Manage coordination services"
echo "  claude-recovery        - Run work recovery"
echo ""
echo "Use 'claude-coordinator help' for coordination options"
EOF
    chmod +x "$TARGET_DIR/.claude/scripts/activate.sh"
    track_file "$TARGET_DIR/.claude/scripts/activate.sh"
    
    # Create bash utilities
    create_bash_utils
    
    # Create zsh utilities
    create_zsh_utils
}

# Create bash-specific utilities
create_bash_utils() {
    cat > "$TARGET_DIR/.claude/scripts/coordination-utils.sh" << 'EOF'
#!/usr/bin/env bash
# Claude Coordination Utilities for Bash

# Configuration
CLAUDE_COORDINATION_DIR="${CLAUDE_PROJECT_ROOT}/.claude/coordination"

# Helper function for date operations
claude_date_offset() {
    local offset=$1
    if [[ "$(uname)" == "Darwin" ]]; then
        date -u -v+${offset}S +"%Y-%m-%dT%H:%M:%SZ"
    else
        date -u -d "+${offset} seconds" +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# Task claiming function
claude-claim() {
    local task_id=$1
    local agent_id=${CLAUDE_AGENT_ID}
    
    if [[ -z "$task_id" ]]; then
        echo "Usage: claude-claim <task_id>"
        return 1
    fi
    
    if [[ -z "$agent_id" ]]; then
        echo "Error: CLAUDE_AGENT_ID not set"
        return 1
    fi
    
    local claim_file="$CLAUDE_COORDINATION_DIR/claims/${task_id}.claim"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local ttl=300
    local expires=$(claude_date_offset $ttl)
    
    # Create claim directory if it doesn't exist
    mkdir -p "$(dirname "$claim_file")"
    mkdir -p "$CLAUDE_COORDINATION_DIR/agents"
    
    # Atomic claim creation
    if (set -C; cat > "${claim_file}" << CLAIM
{
  "agent_id": "${agent_id}",
  "task_id": "${task_id}",
  "claimed_at": "${timestamp}",
  "expires_at": "${expires}",
  "ttl": ${ttl}
}
CLAIM
    ) 2>/dev/null; then
        echo "✓ Task '${task_id}' claimed by ${agent_id}"
        echo "${task_id}" >> "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks"
        return 0
    else
        echo "✗ Task '${task_id}' already claimed"
        if [[ -f "$claim_file" ]] && command -v jq >/dev/null 2>&1; then
            local owner=$(jq -r '.agent_id' "$claim_file" 2>/dev/null)
            echo "  Current owner: $owner"
        fi
        return 1
    fi
}

# Task release function
claude-release() {
    local task_id=$1
    local agent_id=${CLAUDE_AGENT_ID}
    
    if [[ -z "$task_id" ]]; then
        echo "Usage: claude-release <task_id>"
        return 1
    fi
    
    local claim_file="$CLAUDE_COORDINATION_DIR/claims/${task_id}.claim"
    
    if [[ -f "$claim_file" ]]; then
        if command -v jq >/dev/null 2>&1; then
            local owner=$(jq -r '.agent_id' "$claim_file" 2>/dev/null)
            if [[ "$owner" != "$agent_id" ]]; then
                echo "✗ Cannot release task '${task_id}' - owned by $owner"
                return 1
            fi
        fi
        
        rm -f "$claim_file"
        
        # Remove from agent's task list
        if [[ -f "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks" ]]; then
            grep -v "^${task_id}$" "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks" > "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks.tmp" || true
            mv "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks.tmp" "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks"
        fi
        
        echo "✓ Task '${task_id}' released"
        return 0
    else
        echo "✗ Task '${task_id}' not found"
        return 1
    fi
}

# List tasks function
claude-list() {
    local agent_id=${1:-$CLAUDE_AGENT_ID}
    
    echo "=== Tasks for ${agent_id} ==="
    if [[ -f "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks" ]]; then
        while IFS= read -r task_id; do
            [[ -z "$task_id" ]] && continue
            
            local claim_file="$CLAUDE_COORDINATION_DIR/claims/${task_id}.claim"
            if [[ -f "$claim_file" ]]; then
                if command -v jq >/dev/null 2>&1; then
                    local claimed_at=$(jq -r '.claimed_at' "$claim_file" 2>/dev/null)
                    local expires_at=$(jq -r '.expires_at' "$claim_file" 2>/dev/null)
                    echo "  • ${task_id}"
                    echo "    Claimed: ${claimed_at}"
                    echo "    Expires: ${expires_at}"
                else
                    echo "  • ${task_id} (active)"
                fi
            else
                echo "  • ${task_id} (orphaned - claim missing)"
            fi
        done < "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks"
    else
        echo "  No active tasks"
    fi
}

# Cleanup expired claims
claude-cleanup() {
    echo "=== Cleaning expired claims ==="
    local current_time=$(date +%s)
    local cleaned=0
    
    for claim_file in "$CLAUDE_COORDINATION_DIR/claims"/*.claim; do
        [[ -f "$claim_file" ]] || continue
        
        if command -v jq >/dev/null 2>&1; then
            local expires_at=$(jq -r '.expires_at' "$claim_file" 2>/dev/null)
            if [[ -n "$expires_at" ]] && [[ "$expires_at" != "null" ]]; then
                local expire_time=$(date -d "$expires_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null || echo 0)
                
                if (( current_time > expire_time )); then
                    local task_id=$(basename "$claim_file" .claim)
                    local agent_id=$(jq -r '.agent_id' "$claim_file" 2>/dev/null)
                    
                    echo "  Removing expired claim: $task_id (from $agent_id)"
                    rm -f "$claim_file"
                    
                    # Clean up agent task list
                    if [[ -f "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks" ]]; then
                        grep -v "^${task_id}$" "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks" > "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks.tmp" || true
                        mv "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks.tmp" "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks"
                    fi
                    
                    ((cleaned++))
                fi
            fi
        fi
    done
    
    echo "Cleaned $cleaned expired claims"
}

# Status function
claude-status() {
    echo "=== Claude Coordination Status ==="
    echo "Agent ID: ${CLAUDE_AGENT_ID:-Not set}"
    echo "Project Root: ${CLAUDE_PROJECT_ROOT:-Not set}"
    echo ""
    
    local total_claims=$(find "$CLAUDE_COORDINATION_DIR/claims" -name "*.claim" 2>/dev/null | wc -l | tr -d ' ')
    echo "Active claims: $total_claims"
    
    local total_agents=$(find "$CLAUDE_COORDINATION_DIR/agents" -name "*.tasks" -size +0 2>/dev/null | wc -l | tr -d ' ')
    echo "Active agents: $total_agents"
    
    if [[ $total_claims -gt 0 ]]; then
        echo ""
        echo "Recent claims:"
        find "$CLAUDE_COORDINATION_DIR/claims" -name "*.claim" -mmin -10 2>/dev/null | while read -r claim_file; do
            local task_id=$(basename "$claim_file" .claim)
            if command -v jq >/dev/null 2>&1; then
                local agent_id=$(jq -r '.agent_id' "$claim_file" 2>/dev/null)
                local claimed_at=$(jq -r '.claimed_at' "$claim_file" 2>/dev/null)
                echo "  • $task_id by $agent_id at $claimed_at"
            else
                echo "  • $task_id"
            fi
        done | head -5
    fi
}

# Aliases for convenience (these work in bash)
alias claude-claim-task='claude-claim'
alias claude-release-task='claude-release'
alias claude-list-tasks='claude-list'
alias claude-cleanup-claims='claude-cleanup'

# Enhanced coordination aliases
if [[ -f "${CLAUDE_PROJECT_ROOT}/.claude/scripts/workflow-coordinator.sh" ]]; then
    alias claude-coordinator='${CLAUDE_PROJECT_ROOT}/.claude/scripts/workflow-coordinator.sh'
    alias claude-services='${CLAUDE_PROJECT_ROOT}/.claude/scripts/service-manager.sh'
    alias claude-recovery='${CLAUDE_PROJECT_ROOT}/.claude/scripts/work-recovery.sh'
fi

# Bash completion
if [[ -n "$BASH_VERSION" ]]; then
    _claude_completion() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local cmd="${COMP_WORDS[1]}"
        
        case "$cmd" in
            claude-claim|claude-release)
                # Suggest common task types
                COMPREPLY=($(compgen -W "build test lint deploy fix-bug feature docs refactor" -- "$cur"))
                ;;
        esac
    }
    
    complete -F _claude_completion claude-claim claude-release
fi
EOF
    chmod +x "$TARGET_DIR/.claude/scripts/coordination-utils.sh"
    track_file "$TARGET_DIR/.claude/scripts/coordination-utils.sh"
}

# Create zsh-specific utilities
create_zsh_utils() {
    cat > "$TARGET_DIR/.claude/scripts/coordination-utils.zsh" << 'EOF'
#!/usr/bin/env zsh
# Claude Coordination Utilities for ZSH

# Configuration
CLAUDE_COORDINATION_DIR="${CLAUDE_PROJECT_ROOT}/.claude/coordination"

# Helper function for date operations
claude_date_offset() {
    local offset=$1
    if [[ "$(uname)" == "Darwin" ]]; then
        date -u -v+${offset}S +"%Y-%m-%dT%H:%M:%SZ"
    else
        date -u -d "+${offset} seconds" +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# Task claiming function
claude-claim() {
    local task_id=$1
    local agent_id=${CLAUDE_AGENT_ID}
    
    if [[ -z "$task_id" ]]; then
        echo "Usage: claude-claim <task_id>"
        return 1
    fi
    
    if [[ -z "$agent_id" ]]; then
        echo "Error: CLAUDE_AGENT_ID not set"
        return 1
    fi
    
    local claim_file="$CLAUDE_COORDINATION_DIR/claims/${task_id}.claim"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local ttl=300
    local expires=$(claude_date_offset $ttl)
    
    # Create claim directory if it doesn't exist
    mkdir -p "$(dirname "$claim_file")"
    mkdir -p "$CLAUDE_COORDINATION_DIR/agents"
    
    # Atomic claim creation using zsh's noclobber
    if (
        setopt local_options noclobber
        cat > "${claim_file}" << CLAIM
{
  "agent_id": "${agent_id}",
  "task_id": "${task_id}",
  "claimed_at": "${timestamp}",
  "expires_at": "${expires}",
  "ttl": ${ttl}
}
CLAIM
    ) 2>/dev/null; then
        echo "✓ Task '${task_id}' claimed by ${agent_id}"
        echo "${task_id}" >> "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks"
        return 0
    else
        echo "✗ Task '${task_id}' already claimed"
        if [[ -f "$claim_file" ]] && (( $+commands[jq] )); then
            local owner=$(jq -r '.agent_id' "$claim_file" 2>/dev/null)
            echo "  Current owner: $owner"
        fi
        return 1
    fi
}

# Task release function
claude-release() {
    local task_id=$1
    local agent_id=${CLAUDE_AGENT_ID}
    
    if [[ -z "$task_id" ]]; then
        echo "Usage: claude-release <task_id>"
        return 1
    fi
    
    local claim_file="$CLAUDE_COORDINATION_DIR/claims/${task_id}.claim"
    
    if [[ -f "$claim_file" ]]; then
        if (( $+commands[jq] )); then
            local owner=$(jq -r '.agent_id' "$claim_file" 2>/dev/null)
            if [[ "$owner" != "$agent_id" ]]; then
                echo "✗ Cannot release task '${task_id}' - owned by $owner"
                return 1
            fi
        fi
        
        rm -f "$claim_file"
        
        # Remove from agent's task list
        if [[ -f "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks" ]]; then
            grep -v "^${task_id}$" "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks" > "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks.tmp" || true
            mv "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks.tmp" "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks"
        fi
        
        echo "✓ Task '${task_id}' released"
        return 0
    else
        echo "✗ Task '${task_id}' not found"
        return 1
    fi
}

# List tasks function
claude-list() {
    local agent_id=${1:-$CLAUDE_AGENT_ID}
    
    echo "=== Tasks for ${agent_id} ==="
    if [[ -f "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks" ]]; then
        while IFS= read -r task_id; do
            [[ -z "$task_id" ]] && continue
            
            local claim_file="$CLAUDE_COORDINATION_DIR/claims/${task_id}.claim"
            if [[ -f "$claim_file" ]]; then
                if (( $+commands[jq] )); then
                    local claimed_at=$(jq -r '.claimed_at' "$claim_file" 2>/dev/null)
                    local expires_at=$(jq -r '.expires_at' "$claim_file" 2>/dev/null)
                    echo "  • ${task_id}"
                    echo "    Claimed: ${claimed_at}"
                    echo "    Expires: ${expires_at}"
                else
                    echo "  • ${task_id} (active)"
                fi
            else
                echo "  • ${task_id} (orphaned - claim missing)"
            fi
        done < "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks"
    else
        echo "  No active tasks"
    fi
}

# Cleanup expired claims
claude-cleanup() {
    echo "=== Cleaning expired claims ==="
    local current_time=$(date +%s)
    local cleaned=0
    
    for claim_file in "$CLAUDE_COORDINATION_DIR/claims"/*.claim(N); do
        [[ -f "$claim_file" ]] || continue
        
        if (( $+commands[jq] )); then
            local expires_at=$(jq -r '.expires_at' "$claim_file" 2>/dev/null)
            if [[ -n "$expires_at" ]] && [[ "$expires_at" != "null" ]]; then
                # Handle both Linux and macOS date parsing
                local expire_time
                if [[ "$(uname)" == "Darwin" ]]; then
                    expire_time=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null || echo 0)
                else
                    expire_time=$(date -d "$expires_at" +%s 2>/dev/null || echo 0)
                fi
                
                if (( current_time > expire_time )); then
                    local task_id=$(basename "$claim_file" .claim)
                    local agent_id=$(jq -r '.agent_id' "$claim_file" 2>/dev/null)
                    
                    echo "  Removing expired claim: $task_id (from $agent_id)"
                    rm -f "$claim_file"
                    
                    # Clean up agent task list
                    if [[ -f "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks" ]]; then
                        grep -v "^${task_id}$" "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks" > "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks.tmp" || true
                        mv "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks.tmp" "$CLAUDE_COORDINATION_DIR/agents/${agent_id}.tasks"
                    fi
                    
                    ((cleaned++))
                fi
            fi
        fi
    done
    
    echo "Cleaned $cleaned expired claims"
}

# Status function
claude-status() {
    echo "=== Claude Coordination Status ==="
    echo "Agent ID: ${CLAUDE_AGENT_ID:-Not set}"
    echo "Project Root: ${CLAUDE_PROJECT_ROOT:-Not set}"
    echo ""
    
    local total_claims=$(find "$CLAUDE_COORDINATION_DIR/claims" -name "*.claim" 2>/dev/null | wc -l | tr -d ' ')
    echo "Active claims: $total_claims"
    
    local total_agents=$(find "$CLAUDE_COORDINATION_DIR/agents" -name "*.tasks" -size +0c 2>/dev/null | wc -l | tr -d ' ')
    echo "Active agents: $total_agents"
    
    if [[ $total_claims -gt 0 ]]; then
        echo ""
        echo "Recent claims:"
        find "$CLAUDE_COORDINATION_DIR/claims" -name "*.claim" -mmin -10 2>/dev/null | while read -r claim_file; do
            local task_id=$(basename "$claim_file" .claim)
            if (( $+commands[jq] )); then
                local agent_id=$(jq -r '.agent_id' "$claim_file" 2>/dev/null)
                local claimed_at=$(jq -r '.claimed_at' "$claim_file" 2>/dev/null)
                echo "  • $task_id by $agent_id at $claimed_at"
            else
                echo "  • $task_id"
            fi
        done | head -5
    fi
}

# ZSH-specific aliases
alias claude-claim-task='claude-claim'
alias claude-release-task='claude-release'
alias claude-list-tasks='claude-list'
alias claude-cleanup-claims='claude-cleanup'

# Enhanced coordination aliases
if [[ -f "${CLAUDE_PROJECT_ROOT}/.claude/scripts/workflow-coordinator.sh" ]]; then
    alias claude-coordinator='${CLAUDE_PROJECT_ROOT}/.claude/scripts/workflow-coordinator.sh'
    alias claude-services='${CLAUDE_PROJECT_ROOT}/.claude/scripts/service-manager.sh'
    alias claude-recovery='${CLAUDE_PROJECT_ROOT}/.claude/scripts/work-recovery.sh'
fi

# ZSH completion
_claude_completion() {
    local -a tasks
    tasks=(build test lint deploy fix-bug feature docs refactor debug optimize)
    
    case "$words[1]" in
        claude-claim|claude-release)
            _describe 'task' tasks
            ;;
    esac
}

compdef _claude_completion claude-claim claude-release
EOF
    chmod +x "$TARGET_DIR/.claude/scripts/coordination-utils.zsh"
    track_file "$TARGET_DIR/.claude/scripts/coordination-utils.zsh"
}

# Create Docker compose file
create_docker_compose() {
    cat > "$TARGET_DIR/docker-compose.coordination.yml" << 'EOF'
version: '3.8'

services:
  redis-coordinator:
    image: redis:7-alpine
    container_name: claude-redis-coordinator
    ports:
      - "6379:6379"
    volumes:
      - redis_coordination_data:/data
    command: >
      redis-server
      --appendonly yes
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --save 60 1
      --save 300 10
      --save 900 100
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3
  
  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: claude-redis-commander
    environment:
      - REDIS_HOSTS=local:redis-coordinator:6379
    ports:
      - "8081:8081"
    depends_on:
      redis-coordinator:
        condition: service_healthy
    restart: unless-stopped

volumes:
  redis_coordination_data:
    driver: local
EOF
    track_file "$TARGET_DIR/docker-compose.coordination.yml"
}

# Create README
create_readme() {
    cat > "$TARGET_DIR/.claude/README.md" << 'EOF'
# Claude Workflow Framework

This project has been configured with the Claude Workflow Framework for improved coordination between multiple Claude Code instances.

## Quick Start

1. **Activate the framework** (works with both bash and zsh):
   ```bash
   source .claude/scripts/activate.sh
   ```

2. **Check status**:
   ```bash
   claude-status
   ```

3. **Start Redis coordination** (optional but recommended):
   ```bash
   docker-compose -f docker-compose.coordination.yml up -d
   ```

## Available Commands

After activation, these commands are available:

- `claude-claim <task-id>` - Claim a task for exclusive work
- `claude-release <task-id>` - Release a claimed task
- `claude-list [agent-id]` - List tasks for an agent
- `claude-cleanup` - Clean up expired task claims
- `claude-status` - Show coordination system status

## Directory Structure

```
.claude/
├── agent_id                 # Unique identifier for this Claude instance
├── config/                  # Project-specific configuration
│   └── workflow.{json,yml}  # Workflow configuration
├── coordination/            # Coordination data (when using file mode)
│   ├── tasks/              # Available tasks
│   ├── claims/             # Active task claims
│   ├── agents/             # Agent task assignments
│   └── status/             # Status information
├── scripts/                # Utility scripts
│   ├── activate.sh         # Main activation script
│   ├── coordination-utils.sh   # Bash utilities
│   └── coordination-utils.zsh  # ZSH utilities
├── docs/                   # Framework documentation
├── rules/                  # Workflow rules and governance
├── terminology/            # Shared terminology
└── logs/                   # Operation logs
```

## Configuration

The workflow configuration is stored in `.claude/config/workflow.{json,yml}` and includes:

- **Coordination mode**: Redis (recommended) or file-based
- **Task definitions**: Common project tasks
- **Quality gates**: Pre-commit, pre-merge, and pre-deploy checks
- **Agent settings**: Concurrency limits and specializations

## Task Coordination

### Claiming a Task

```bash
# Claim a task exclusively
claude-claim fix-login-bug

# Task is now locked to your agent for 5 minutes (TTL)
```

### Working on Tasks

```bash
# List your active tasks
claude-list

# When done, release the task
claude-release fix-login-bug
```

### Automatic Cleanup

Tasks have a 5-minute TTL by default. Expired claims are automatically cleaned up:

```bash
claude-cleanup
```

## Redis Coordination (Recommended)

For better performance and reliability with multiple Claude instances:

1. Start Redis:
   ```bash
   docker-compose -f docker-compose.coordination.yml up -d
   ```

2. Monitor Redis (optional):
   - Redis Commander: http://localhost:8081

3. Stop Redis:
   ```bash
   docker-compose -f docker-compose.coordination.yml down
   ```

## Shell Integration

### Bash
Add to your `~/.bashrc`:
```bash
if [ -f "/path/to/project/.claude/scripts/activate.sh" ]; then
    source "/path/to/project/.claude/scripts/activate.sh"
fi
```

### ZSH
Add to your `~/.zshrc`:
```zsh
if [ -f "/path/to/project/.claude/scripts/activate.sh" ]; then
    source "/path/to/project/.claude/scripts/activate.sh"
fi
```

## Troubleshooting

### Command not found
- Ensure you've run `source .claude/scripts/activate.sh`
- Check that `CLAUDE_AGENT_ID` is set: `echo $CLAUDE_AGENT_ID`

### Cannot claim tasks
- Check if the task is already claimed: `ls .claude/coordination/claims/`
- Clean up expired claims: `claude-cleanup`

### Redis connection issues
- Verify Redis is running: `docker ps`
- Test connection: `redis-cli ping`

## Further Documentation

- **Coordination Plan**: `.claude/CLAUDE_COORDINATION_PLAN.md`
- **Implementation Guide**: `.claude/IMPLEMENTATION_GUIDE.md`
- **Workflow Rules**: `.claude/rules/workflow-governance.md`
- **Best Practices**: `.claude/docs/claude-code-best-practices.md`
EOF
    track_file "$TARGET_DIR/.claude/README.md"
}

# Verify installation
verify_installation() {
    local errors=0
    
    # Check essential files
    local essential_files=(
        "$TARGET_DIR/.claude/CLAUDE.md"
        "$TARGET_DIR/.claude/agent_id"
        "$TARGET_DIR/.claude/README.md"
        "$TARGET_DIR/.claude/scripts/activate.sh"
        "$TARGET_DIR/docker-compose.coordination.yml"
    )
    
    # Check enhanced coordination scripts if they should exist
    if [[ -d "$SCRIPT_DIR/scripts" ]]; then
        essential_files+=(
            "$TARGET_DIR/.claude/scripts/service-manager.sh"
            "$TARGET_DIR/.claude/scripts/work-recovery.sh"
            "$TARGET_DIR/.claude/scripts/workflow-coordinator.sh"
        )
    fi
    
    for file in "${essential_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Missing essential file: $file"
            ((errors++))
        fi
    done
    
    # Check essential directories
    local essential_dirs=(
        "$TARGET_DIR/.claude/config"
        "$TARGET_DIR/.claude/coordination"
        "$TARGET_DIR/.claude/scripts"
        "$TARGET_DIR/.claude/docs"
    )
    
    for dir in "${essential_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            error "Missing essential directory: $dir"
            ((errors++))
        fi
    done
    
    # Check configuration file exists
    if [[ ! -f "$TARGET_DIR/.claude/config/workflow.json" ]] && [[ ! -f "$TARGET_DIR/.claude/config/workflow.yml" ]]; then
        error "Missing workflow configuration"
        ((errors++))
    fi
    
    return $errors
}

# Run main installation
main "$@"