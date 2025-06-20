#!/bin/bash
# Claude Workflow Framework Installation Script
# Usage: ./install-framework.sh [target-directory]

set -e

TARGET_DIR="${1:-.}"

echo "=== Claude Workflow Framework Installation ==="
echo "Target directory: $TARGET_DIR"

# Detect framework directory dynamically
detect_framework_dir() {
    # Check if we're running from within the framework directory
    if [[ -f "CLAUDE.md" && -f "README.md" && -d "concurrency" ]]; then
        echo "$(pwd)"
        return 0
    fi
    
    # Check common locations
    local common_paths=(
        "$HOME/claude-workflow-framework"
        "$HOME/Documents/code/workflow-ng"
        "$HOME/workflow-ng"
        "$(dirname "$0")"
    )
    
    for path in "${common_paths[@]}"; do
        if [[ -d "$path" && -f "$path/CLAUDE.md" && -d "$path/concurrency" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    # Search in current directory and parent directories
    local search_dir="$(pwd)"
    while [[ "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/CLAUDE.md" && -d "$search_dir/concurrency" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir="$(dirname "$search_dir")"
    done
    
    return 1
}

FRAMEWORK_DIR=$(detect_framework_dir)
if [[ -z "$FRAMEWORK_DIR" ]]; then
    echo "Error: Could not locate framework directory"
    echo "Please ensure you're running this script from the framework directory"
    echo "or that the framework is installed in one of these locations:"
    echo "  - $HOME/claude-workflow-framework"
    echo "  - $HOME/Documents/code/workflow-ng" 
    echo "  - $HOME/workflow-ng"
    exit 1
fi

echo "Framework source: $FRAMEWORK_DIR"

# Validate target directory
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Target directory '$TARGET_DIR' does not exist"
    exit 1
fi

# Helper function to safely copy files
safe_copy() {
    local src="$1"
    local dest="$2"
    local description="$3"
    
    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        echo "✓ Copied $description"
    elif [[ -d "$src" ]]; then
        cp -r "$src" "$dest"
        echo "✓ Copied $description"
    else
        echo "⚠ Skipped $description (not found: $src)"
    fi
}

# Create .claude directory structure
echo "Creating .claude directory structure..."
mkdir -p "$TARGET_DIR/.claude"/{config,coordination,scripts,templates,metrics,logs}

# Copy configuration templates to .claude directory (DO NOT overwrite project root CLAUDE.md)
echo "Installing configuration templates..."
safe_copy "$FRAMEWORK_DIR/CLAUDE.md" "$TARGET_DIR/.claude/" "CLAUDE.md configuration (to .claude directory)"

# Safe CLAUDE.md integration
echo "Handling CLAUDE.md integration..."
if [[ -f "$FRAMEWORK_DIR/scripts/claude-md-integration.sh" ]]; then
    "$FRAMEWORK_DIR/scripts/claude-md-integration.sh" auto "$TARGET_DIR" safe
else
    echo "⚠ CLAUDE.md integration script not found - skipping root CLAUDE.md modification"
    echo "Framework documentation available in .claude/README.md"
fi

# Copy implementation guides
echo "Installing implementation guides..."
safe_copy "$FRAMEWORK_DIR/CLAUDE_COORDINATION_PLAN.md" "$TARGET_DIR/.claude/" "coordination plan"
safe_copy "$FRAMEWORK_DIR/IMPLEMENTATION_GUIDE.md" "$TARGET_DIR/.claude/" "implementation guide"
safe_copy "$FRAMEWORK_DIR/EXPERT_QUICK_REFERENCE.md" "$TARGET_DIR/.claude/" "Expert system quick reference"

# Copy essential scripts
echo "Installing coordination scripts..."
mkdir -p "$TARGET_DIR/.claude/scripts"

# Copy enhanced coordination scripts
safe_copy "$FRAMEWORK_DIR/scripts/workflow-coordinator.sh" "$TARGET_DIR/.claude/scripts/" "workflow coordinator"
safe_copy "$FRAMEWORK_DIR/scripts/service-manager.sh" "$TARGET_DIR/.claude/scripts/" "service manager"
safe_copy "$FRAMEWORK_DIR/scripts/work-recovery.sh" "$TARGET_DIR/.claude/scripts/" "work recovery"
safe_copy "$FRAMEWORK_DIR/scripts/redis-file-builder.sh" "$TARGET_DIR/.claude/scripts/" "Redis file builder"
safe_copy "$FRAMEWORK_DIR/scripts/workflow-file-ops.sh" "$TARGET_DIR/.claude/scripts/" "workflow file operations"
safe_copy "$FRAMEWORK_DIR/scripts/expert-enhanced-planner.sh" "$TARGET_DIR/.claude/scripts/" "expert-enhanced planner"
safe_copy "$FRAMEWORK_DIR/scripts/expert-guided-implementation.sh" "$TARGET_DIR/.claude/scripts/" "expert-guided implementation"
safe_copy "$FRAMEWORK_DIR/scripts/expert-testing-deployment.sh" "$TARGET_DIR/.claude/scripts/" "expert testing and deployment"
safe_copy "$FRAMEWORK_DIR/scripts/claude-md-integration.sh" "$TARGET_DIR/.claude/scripts/" "CLAUDE.md integration helper"

# Make scripts executable
chmod +x "$TARGET_DIR/.claude/scripts"/*.sh 2>/dev/null || true

# Create coordination setup script
cat > "$TARGET_DIR/.claude/scripts/setup-coordination.sh" << 'EOF'
#!/bin/bash
# Auto-generated coordination setup script

# Detect project type
detect_project_type() {
    if [[ -f "package.json" ]]; then
        echo "node"
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        echo "python"
    elif [[ -f "go.mod" ]]; then
        echo "go"
    elif [[ -f "Cargo.toml" ]]; then
        echo "rust"
    else
        echo "unknown"
    fi
}

# Setup based on project type
PROJECT_TYPE=$(detect_project_type)
echo "Detected project type: $PROJECT_TYPE"

# Create appropriate workflow configuration
case $PROJECT_TYPE in
    "node")
        cat > .claude/config/workflow.json << 'NODEEOF'
{
  "coordination": {
    "mode": "redis",
    "fallback": "file",
    "redis_url": "redis://localhost:6379"
  },
  "tasks": {
    "test": "npm test",
    "lint": "npm run lint",
    "build": "npm run build",
    "type_check": "npm run type-check"
  },
  "agents": {
    "max_concurrent_tasks": 3,
    "specializations": ["frontend", "backend", "testing", "documentation"]
  },
  "quality_gates": {
    "pre_commit": ["lint", "type_check", "test"],
    "pre_merge": ["build", "integration_test"]
  }
}
NODEEOF
        ;;
    "python")
        cat > .claude/config/workflow.yml << 'PYTHONEOF'
coordination:
  mode: redis
  fallback: file
  redis_url: redis://localhost:6379

tasks:
  test: pytest
  lint: ruff check .
  format: black .
  type_check: mypy .
  security: bandit -r .

agents:
  max_concurrent_tasks: 3
  specializations:
    - data_processing
    - api_development
    - testing
    - ml_ops

quality_gates:
  pre_commit:
    - lint
    - type_check
    - test
  pre_deploy:
    - security
    - integration_test
PYTHONEOF
        ;;
    "go")
        cat > .claude/config/workflow.yml << 'GOEOF'
coordination:
  mode: redis
  fallback: file
  redis_url: redis://localhost:6379

tasks:
  test: go test ./...
  lint: golangci-lint run
  build: go build ./...
  vet: go vet ./...
  mod_tidy: go mod tidy

agents:
  max_concurrent_tasks: 3
  specializations:
    - backend_development
    - microservices
    - testing
    - performance

quality_gates:
  pre_commit:
    - vet
    - lint
    - test
  pre_deploy:
    - build
    - integration_test
GOEOF
        ;;
    *)
        cat > .claude/config/workflow.yml << 'GENERICEOF'
coordination:
  mode: file
  fallback: file

tasks:
  test: echo "No test command configured"
  lint: echo "No lint command configured"
  build: echo "No build command configured"

agents:
  max_concurrent_tasks: 3
  specializations:
    - development
    - testing
    - documentation

quality_gates:
  pre_commit: []
  pre_deploy: []
GENERICEOF
        ;;
esac

# Setup coordination directories for file-based fallback
mkdir -p .claude/coordination/{tasks,claims,agents,status,logs}

# Generate agent ID
AGENT_ID="claude-$(hostname)-$(date +%s)"
echo "$AGENT_ID" > .claude/agent_id

echo "=== Setup Complete ==="
echo "Agent ID: $AGENT_ID"
echo "Project type: $PROJECT_TYPE"
echo "Configuration created in .claude/config/"
echo ""
echo "Next steps:"
echo "1. Review configuration in .claude/config/"
echo "2. Start Redis if using Redis coordination: docker run -d -p 6379:6379 redis:7-alpine"
echo "3. Run: source .claude/scripts/coordination-utils.sh"
echo "4. Test with: claude-claim-task test-task \$AGENT_ID"
EOF

chmod +x "$TARGET_DIR/.claude/scripts/setup-coordination.sh"

# Copy coordination utilities
cat > "$TARGET_DIR/.claude/scripts/coordination-utils.sh" << 'EOF'
#!/bin/bash
# Claude Coordination Utilities

# Load agent ID
if [[ -f ".claude/agent_id" ]]; then
    CLAUDE_AGENT_ID=$(cat .claude/agent_id)
    export CLAUDE_AGENT_ID
fi

# Task claiming functions
claude-claim-task() {
    local task_id=$1
    local agent_id=${2:-$CLAUDE_AGENT_ID}
    
    if [[ -z "$task_id" ]] || [[ -z "$agent_id" ]]; then
        echo "Usage: claude-claim-task <task_id> [agent_id]"
        return 1
    fi
    
    local claim_file=".claude/coordination/claims/${task_id}.claim"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Atomic claim creation
    if (set -C; echo "{\"agent_id\":\"${agent_id}\",\"claimed_at\":\"${timestamp}\",\"ttl\":300}" > "${claim_file}") 2>/dev/null; then
        echo "✓ Task ${task_id} claimed by ${agent_id}"
        echo "${task_id}" >> ".claude/coordination/agents/${agent_id}.tasks"
        return 0
    else
        echo "✗ Task ${task_id} already claimed"
        return 1
    fi
}

claude-release-task() {
    local task_id=$1
    local agent_id=${2:-$CLAUDE_AGENT_ID}
    
    if [[ -z "$task_id" ]] || [[ -z "$agent_id" ]]; then
        echo "Usage: claude-release-task <task_id> [agent_id]"
        return 1
    fi
    
    local claim_file=".claude/coordination/claims/${task_id}.claim"
    
    if [[ -f "${claim_file}" ]]; then
        local claimed_by=$(jq -r '.agent_id' "${claim_file}" 2>/dev/null || echo "unknown")
        if [[ "${claimed_by}" == "${agent_id}" ]]; then
            rm -f "${claim_file}"
            if [[ -f ".claude/coordination/agents/${agent_id}.tasks" ]]; then
                sed -i.bak "/${task_id}/d" ".claude/coordination/agents/${agent_id}.tasks"
                rm -f ".claude/coordination/agents/${agent_id}.tasks.bak"
            fi
            echo "✓ Task ${task_id} released by ${agent_id}"
            return 0
        else
            echo "✗ Task ${task_id} not claimed by ${agent_id} (claimed by: ${claimed_by})"
            return 1
        fi
    else
        echo "✗ Task ${task_id} not found or not claimed"
        return 1
    fi
}

claude-list-tasks() {
    local agent_id=${1:-$CLAUDE_AGENT_ID}
    
    echo "=== Active Tasks for ${agent_id} ==="
    if [[ -f ".claude/coordination/agents/${agent_id}.tasks" ]]; then
        while read -r task_id; do
            [[ -n "$task_id" ]] || continue
            local claim_file=".claude/coordination/claims/${task_id}.claim"
            if [[ -f "$claim_file" ]]; then
                local claimed_at=$(jq -r '.claimed_at' "$claim_file" 2>/dev/null || echo "unknown")
                echo "  $task_id (claimed: $claimed_at)"
            else
                echo "  $task_id (claim missing - orphaned)"
            fi
        done < ".claude/coordination/agents/${agent_id}.tasks"
    else
        echo "  No active tasks"
    fi
}

claude-cleanup-claims() {
    echo "=== Cleaning up expired claims ==="
    local current_time=$(date +%s)
    local cleaned=0
    
    for claim_file in .claude/coordination/claims/*.claim; do
        [[ -f "$claim_file" ]] || continue
        
        local claimed_at=$(jq -r '.claimed_at' "$claim_file" 2>/dev/null)
        local ttl=$(jq -r '.ttl' "$claim_file" 2>/dev/null)
        
        if [[ "$claimed_at" != "null" ]] && [[ "$ttl" != "null" ]]; then
            local claim_time=$(date -d "$claimed_at" +%s 2>/dev/null || echo 0)
            
            if (( current_time > claim_time + ttl )); then
                local task_id=$(basename "$claim_file" .claim)
                local agent_id=$(jq -r '.agent_id' "$claim_file" 2>/dev/null)
                
                echo "  Cleaning expired claim: $task_id from $agent_id"
                rm -f "$claim_file"
                
                if [[ -f ".claude/coordination/agents/${agent_id}.tasks" ]]; then
                    sed -i.bak "/${task_id}/d" ".claude/coordination/agents/${agent_id}.tasks"
                    rm -f ".claude/coordination/agents/${agent_id}.tasks.bak"
                fi
                ((cleaned++))
            fi
        fi
    done
    
    echo "Cleaned $cleaned expired claims"
}

claude-status() {
    echo "=== Claude Coordination Status ==="
    echo "Agent ID: ${CLAUDE_AGENT_ID:-Not set}"
    
    local total_claims=$(find .claude/coordination/claims -name "*.claim" 2>/dev/null | wc -l)
    echo "Total active claims: $total_claims"
    
    local total_agents=$(find .claude/coordination/agents -name "*.tasks" 2>/dev/null | wc -l)
    echo "Total agents with tasks: $total_agents"
    
    echo ""
    echo "Recent activity:"
    find .claude/coordination/claims -name "*.claim" -mmin -5 2>/dev/null | while read -r claim_file; do
        local task_id=$(basename "$claim_file" .claim)
        local agent_id=$(jq -r '.agent_id' "$claim_file" 2>/dev/null)
        local claimed_at=$(jq -r '.claimed_at' "$claim_file" 2>/dev/null)
        echo "  $task_id claimed by $agent_id at $claimed_at"
    done
}

# Auto-completion for common tasks
_claude_tasks_completion() {
    local cur prev opts
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    case "${prev}" in
        claude-claim-task|claude-release-task)
            # Suggest common task types
            opts="build test lint deploy documentation refactor"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
    esac
}

complete -F _claude_tasks_completion claude-claim-task claude-release-task

echo "Claude coordination utilities loaded!"
echo "Commands available:"
echo "  claude-claim-task <task_id> [agent_id]"
echo "  claude-release-task <task_id> [agent_id]"
echo "  claude-list-tasks [agent_id]"
echo "  claude-cleanup-claims"
echo "  claude-status"
EOF

# Copy essential documentation
echo "Copying documentation..."
safe_copy "$FRAMEWORK_DIR/docs" "$TARGET_DIR/.claude/" "documentation"
safe_copy "$FRAMEWORK_DIR/rules" "$TARGET_DIR/.claude/" "workflow rules"
safe_copy "$FRAMEWORK_DIR/terminology" "$TARGET_DIR/.claude/" "terminology"
safe_copy "$FRAMEWORK_DIR/api" "$TARGET_DIR/.claude/" "API patterns"

# Create project-specific docker-compose for Redis coordination
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
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    restart: unless-stopped
    
  coordination-monitor:
    image: grafana/grafana:latest
    container_name: claude-coordination-monitor
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_coordination_data:/var/lib/grafana
    restart: unless-stopped
    depends_on:
      - redis-coordinator

volumes:
  redis_coordination_data:
  grafana_coordination_data:
EOF

# Create README for the project
cat > "$TARGET_DIR/.claude/README.md" << 'EOF'
# Claude Workflow Framework

This project has been set up with the Claude Workflow Framework for improved coordination between multiple Claude Code instances.

## Quick Start

1. **Setup coordination infrastructure:**
   ```bash
   cd .claude/scripts
   ./setup-coordination.sh
   ```

2. **Start Redis coordination (recommended):**
   ```bash
   docker-compose -f docker-compose.coordination.yml up -d
   ```

3. **Load coordination utilities:**
   ```bash
   source .claude/scripts/coordination-utils.sh
   ```

4. **Test the setup:**
   ```bash
   claude-claim-task example-task
   claude-list-tasks
   claude-release-task example-task
   claude-status
   ```

## Available Commands

- `claude-claim-task <task_id>` - Claim a task for this agent
- `claude-release-task <task_id>` - Release a claimed task
- `claude-list-tasks` - List active tasks for this agent
- `claude-cleanup-claims` - Clean up expired task claims
- `claude-status` - Show coordination system status

## Configuration

- **Workflow config**: `.claude/config/workflow.yml` or `.claude/config/workflow.json`
- **Agent ID**: `.claude/agent_id`
- **Coordination data**: `.claude/coordination/`

## Documentation

- **Implementation Guide**: `.claude/IMPLEMENTATION_GUIDE.md`
- **Coordination Plan**: `.claude/CLAUDE_COORDINATION_PLAN.md`
- **API Patterns**: `.claude/api/` (if copied)
- **Rules & Governance**: `.claude/rules/`

## Troubleshooting

If you encounter issues:

1. Check Redis connectivity: `redis-cli ping`
2. Verify agent registration: `claude-status`
3. Clean up orphaned claims: `claude-cleanup-claims`
4. Review logs in `.claude/logs/`

For more detailed information, see the implementation guide and coordination plan in the `.claude/` directory.
EOF

echo ""
echo "✅ Claude Workflow Framework with Expert Knowledge Base installed successfully!"
echo ""
echo "🔒 CLAUDE.md Protection: Existing CLAUDE.md files are preserved!"
echo "   - Framework content stored in .claude/CLAUDE.md"
echo "   - Project root CLAUDE.md left untouched for /init compatibility"
echo ""
echo "🧠 EXPERT SYSTEM: 85,000+ knowledge chunks across 73 domains now available!"
echo "⚡ REDIS FILE BUILDING: In-memory atomic operations eliminate I/O bottlenecks!"
echo "🎯 AI-GUIDED WORKFLOWS: Context-aware recommendations for all development phases!"
echo ""
echo "🚀 Quick Start:"
echo "1. cd $TARGET_DIR"
echo "2. source .claude/scripts/activate.sh"
echo "3. claude-coordinator start-with-fallback"
echo ""
echo "🧠 Test Expert Knowledge Base:"
echo "4. claude-coordinator expert-status"
echo "5. .claude/scripts/expert-enhanced-planner.sh detect"
echo "6. .claude/scripts/expert-guided-implementation.sh guide \"your-feature\" \"technology\""
echo ""
echo "⚡ Test Redis File Building:"
echo "7. claude-coordinator test-file-ops"
echo "8. claude-coordinator file-buffers"
echo ""
echo "📚 Documentation:"
echo "   - Quick Start: .claude/README.md"
echo "   - Expert Guide: .claude/EXPERT_QUICK_REFERENCE.md"
echo "   - Integration Guide: .claude/docs/expert-system-integration.md"
echo ""
echo "Optional: Integrate framework content into your CLAUDE.md:"
echo "   .claude/scripts/claude-md-integration.sh integrate $TARGET_DIR"