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

# Only enable completion if we're in an interactive bash shell
if [[ -n "$BASH_VERSION" ]] && [[ "$-" == *i* ]]; then
    complete -F _claude_tasks_completion claude-claim-task claude-release-task 2>/dev/null || true
fi

echo "Claude coordination utilities loaded!"
echo "Commands available:"
echo "  claude-claim-task <task_id> [agent_id]"
echo "  claude-release-task <task_id> [agent_id]"
echo "  claude-list-tasks [agent_id]"
echo "  claude-cleanup-claims"
echo "  claude-status"