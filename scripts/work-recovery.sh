#!/usr/bin/env bash
# Work Recovery System for Claude Workflow Framework
# Handles orphaned work detection and recovery mechanisms

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORK_CLAIMS_DIR="$PROJECT_ROOT/work-claims"
TASKS_DIR="$PROJECT_ROOT/tasks"
RECOVERY_LOG="$PROJECT_ROOT/.work-recovery.log"
REDIS_URL="${REDIS_URL:-redis://localhost:6379}"

# Timing configuration (in seconds)
CLAIM_TTL=300           # 5 minutes - how long claims are valid
STALE_THRESHOLD=600     # 10 minutes - when to consider work stale
ORPHAN_THRESHOLD=1800   # 30 minutes - when to mark work as orphaned
EARLY_FAILURE_WINDOW=120 # 2 minutes - early stage failure window

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $*"
    echo -e "${GREEN}${message}${NC}"
    echo "$message" >> "$RECOVERY_LOG"
}

error() {
    local message="[ERROR] $*"
    echo -e "${RED}${message}${NC}" >&2
    echo "$message" >> "$RECOVERY_LOG"
}

warn() {
    local message="[WARN] $*"
    echo -e "${YELLOW}${message}${NC}"
    echo "$message" >> "$RECOVERY_LOG"
}

info() {
    local message="[INFO] $*"
    echo -e "${BLUE}${message}${NC}"
    echo "$message" >> "$RECOVERY_LOG"
}

# Initialize recovery system
init_recovery_system() {
    mkdir -p "$WORK_CLAIMS_DIR" "$TASKS_DIR" "$(dirname "$RECOVERY_LOG")"
    
    # Initialize log
    if [ ! -f "$RECOVERY_LOG" ]; then
        echo "Work Recovery System - $(date)" > "$RECOVERY_LOG"
    fi
    
    log "Work recovery system initialized"
}

# Get current timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get timestamp from seconds ago
get_past_timestamp() {
    local seconds_ago=$1
    if [[ "$(uname -s)" == "Darwin" ]]; then
        date -u -v-${seconds_ago}S +"%Y-%m-%dT%H:%M:%SZ"
    else
        date -u -d "${seconds_ago} seconds ago" +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# Parse timestamp to epoch seconds
timestamp_to_epoch() {
    local timestamp=$1
    if [[ "$(uname -s)" == "Darwin" ]]; then
        date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S%z" "$timestamp" +%s
    else
        date -d "$timestamp" +%s
    fi
}

# Check if Redis is available
check_redis_available() {
    if command -v redis-cli >/dev/null 2>&1; then
        redis-cli -u "$REDIS_URL" ping >/dev/null 2>&1
    else
        return 1
    fi
}

# Redis-based orphan detection
detect_redis_orphans() {
    if ! check_redis_available; then
        warn "Redis not available, skipping Redis-based orphan detection"
        return 0
    fi
    
    info "Checking for orphaned work in Redis..."
    local current_time
    current_time=$(date +%s)
    local orphans_found=0
    
    # Get all task claims from Redis
    local claim_keys
    claim_keys=$(redis-cli -u "$REDIS_URL" KEYS "task:claim:*" 2>/dev/null | tr '\n' ' ')
    
    for claim_key in $claim_keys; do
        if [ -z "$claim_key" ]; then continue; fi
        
        local claim_data
        claim_data=$(redis-cli -u "$REDIS_URL" GET "$claim_key" 2>/dev/null)
        
        if [ -n "$claim_data" ]; then
            local claimed_at
            claimed_at=$(echo "$claim_data" | jq -r '.claimed_at // empty' 2>/dev/null)
            
            if [ -n "$claimed_at" ]; then
                local age=$((current_time - ${claimed_at%.*}))  # Remove decimal if present
                
                if [ $age -gt $ORPHAN_THRESHOLD ]; then
                    local task_id
                    task_id=$(echo "$claim_key" | sed 's/task:claim://')
                    local agent_id
                    agent_id=$(echo "$claim_data" | jq -r '.agent_id // "unknown"' 2>/dev/null)
                    
                    warn "Orphaned Redis claim detected: $task_id (agent: $agent_id, age: ${age}s)"
                    recover_redis_orphan "$task_id" "$claim_key" "$agent_id"
                    ((orphans_found++))
                fi
            fi
        fi
    done
    
    if [ $orphans_found -eq 0 ]; then
        log "No Redis orphans detected"
    else
        warn "Recovered $orphans_found Redis orphans"
    fi
}

# File-based orphan detection
detect_file_orphans() {
    info "Checking for orphaned work in file system..."
    local orphans_found=0
    
    if [ ! -d "$WORK_CLAIMS_DIR" ]; then
        info "Work claims directory not found, skipping file-based detection"
        return 0
    fi
    
    local current_time
    current_time=$(date +%s)
    
    # Check claim files
    for claim_file in "$WORK_CLAIMS_DIR"/*.json; do
        if [ ! -f "$claim_file" ]; then continue; fi
        
        local claim_data
        if ! claim_data=$(cat "$claim_file" 2>/dev/null); then
            warn "Could not read claim file: $claim_file"
            continue
        fi
        
        local claimed_at
        claimed_at=$(echo "$claim_data" | jq -r '.claimed_at // .startTime // empty' 2>/dev/null)
        
        if [ -n "$claimed_at" ]; then
            local claimed_epoch
            if ! claimed_epoch=$(timestamp_to_epoch "$claimed_at"); then
                warn "Could not parse timestamp in $claim_file: $claimed_at"
                continue
            fi
            
            local age=$((current_time - claimed_epoch))
            local status
            status=$(echo "$claim_data" | jq -r '.status // "unknown"' 2>/dev/null)
            
            # Check for different types of orphaned work
            if [ "$status" = "in_progress" ] && [ $age -gt $ORPHAN_THRESHOLD ]; then
                local task_id
                task_id=$(basename "$claim_file" .json)
                local agent_id
                agent_id=$(echo "$claim_data" | jq -r '.agent_id // .instanceId // "unknown"' 2>/dev/null)
                
                warn "Orphaned file claim detected: $task_id (agent: $agent_id, age: ${age}s)"
                recover_file_orphan "$claim_file" "$task_id" "$agent_id"
                ((orphans_found++))
            elif [ "$status" = "failed" ] && [ $age -lt $EARLY_FAILURE_WINDOW ]; then
                # Early stage failure - potentially recoverable
                local task_id
                task_id=$(basename "$claim_file" .json)
                
                info "Early stage failure detected: $task_id (age: ${age}s) - marking for recovery"
                resurrect_failed_work "$claim_file" "$task_id"
                ((orphans_found++))
            fi
        fi
    done
    
    if [ $orphans_found -eq 0 ]; then
        log "No file-based orphans detected"
    else
        warn "Recovered $orphans_found file-based orphans"
    fi
}

# Recover Redis-based orphaned work
recover_redis_orphan() {
    local task_id=$1
    local claim_key=$2
    local agent_id=$3
    
    info "Recovering Redis orphan: $task_id"
    
    # Remove the stale claim
    redis-cli -u "$REDIS_URL" DEL "$claim_key" >/dev/null 2>&1
    
    # Remove from agent's task set
    redis-cli -u "$REDIS_URL" SREM "agent:tasks:$agent_id" "$task_id" >/dev/null 2>&1
    
    # Add back to available work queue with recovery metadata
    local recovery_data
    recovery_data=$(cat <<EOF
{
    "task_id": "$task_id",
    "recovery_reason": "orphaned_claim",
    "original_agent": "$agent_id",
    "recovered_at": "$(get_timestamp)",
    "priority": "high"
}
EOF
)
    
    # Add to high-priority queue for immediate reassignment
    redis-cli -u "$REDIS_URL" LPUSH "work:available:high" "$recovery_data" >/dev/null 2>&1
    
    # Log recovery
    redis-cli -u "$REDIS_URL" LPUSH "recovery:log" "$(cat <<EOF
{
    "type": "redis_orphan_recovery",
    "task_id": "$task_id",
    "original_agent": "$agent_id",
    "recovered_at": "$(get_timestamp)"
}
EOF
)" >/dev/null 2>&1
    
    log "Redis orphan recovered and queued for reassignment: $task_id"
}

# Recover file-based orphaned work
recover_file_orphan() {
    local claim_file=$1
    local task_id=$2
    local agent_id=$3
    
    info "Recovering file orphan: $task_id"
    
    # Create recovery record
    local recovery_file="$WORK_CLAIMS_DIR/${task_id}.recovery.json"
    cat > "$recovery_file" <<EOF
{
    "task_id": "$task_id",
    "recovery_reason": "orphaned_claim",
    "original_agent": "$agent_id",
    "original_claim_file": "$claim_file",
    "recovered_at": "$(get_timestamp)",
    "status": "recovered",
    "priority": "high"
}
EOF
    
    # Move original claim to orphaned directory
    local orphaned_dir="$WORK_CLAIMS_DIR/orphaned"
    mkdir -p "$orphaned_dir"
    mv "$claim_file" "$orphaned_dir/$(basename "$claim_file").$(date +%s)"
    
    # Make task available for reassignment
    if [ -d "$TASKS_DIR" ]; then
        local task_file="$TASKS_DIR/${task_id}.available"
        echo "$(get_timestamp)" > "$task_file"
    fi
    
    log "File orphan recovered and available for reassignment: $task_id"
}

# Resurrect failed work that failed early
resurrect_failed_work() {
    local claim_file=$1
    local task_id=$2
    
    info "Resurrecting early-stage failed work: $task_id"
    
    # Update the claim status to available for retry
    local updated_claim
    updated_claim=$(jq '. + {
        "status": "retry_available",
        "resurrection_time": "'$(get_timestamp)'",
        "retry_count": (.retry_count // 0) + 1,
        "priority": "high"
    }' "$claim_file")
    
    echo "$updated_claim" > "$claim_file"
    
    # If using Redis, also add to retry queue
    if check_redis_available; then
        redis-cli -u "$REDIS_URL" LPUSH "work:retry:high" "$updated_claim" >/dev/null 2>&1
    fi
    
    log "Early-stage failed work resurrected for retry: $task_id"
}

# Check for stale heartbeats
check_stale_heartbeats() {
    info "Checking for stale heartbeats..."
    local stale_found=0
    
    if check_redis_available; then
        # Check Redis-based heartbeats
        local current_time
        current_time=$(date +%s)
        
        local agent_keys
        agent_keys=$(redis-cli -u "$REDIS_URL" KEYS "agent:heartbeat:*" 2>/dev/null | tr '\n' ' ')
        
        for agent_key in $agent_keys; do
            if [ -z "$agent_key" ]; then continue; fi
            
            local last_heartbeat
            last_heartbeat=$(redis-cli -u "$REDIS_URL" GET "$agent_key" 2>/dev/null)
            
            if [ -n "$last_heartbeat" ]; then
                local age=$((current_time - ${last_heartbeat%.*}))
                
                if [ $age -gt $STALE_THRESHOLD ]; then
                    local agent_id
                    agent_id=$(echo "$agent_key" | sed 's/agent:heartbeat://')
                    
                    warn "Stale heartbeat detected: $agent_id (age: ${age}s)"
                    handle_stale_agent "$agent_id"
                    ((stale_found++))
                fi
            fi
        done
    fi
    
    if [ $stale_found -eq 0 ]; then
        log "No stale heartbeats detected"
    else
        warn "Found $stale_found stale heartbeats"
    fi
}

# Handle stale agent - recover its work
handle_stale_agent() {
    local agent_id=$1
    
    info "Handling stale agent: $agent_id"
    
    if check_redis_available; then
        # Get all tasks claimed by this agent
        local agent_tasks
        agent_tasks=$(redis-cli -u "$REDIS_URL" SMEMBERS "agent:tasks:$agent_id" 2>/dev/null | tr '\n' ' ')
        
        for task_id in $agent_tasks; do
            if [ -n "$task_id" ]; then
                warn "Recovering task from stale agent: $task_id"
                recover_redis_orphan "$task_id" "task:claim:$task_id" "$agent_id"
            fi
        done
        
        # Clean up agent's data
        redis-cli -u "$REDIS_URL" DEL "agent:heartbeat:$agent_id" >/dev/null 2>&1
        redis-cli -u "$REDIS_URL" DEL "agent:tasks:$agent_id" >/dev/null 2>&1
    fi
    
    log "Stale agent handled: $agent_id"
}

# Generate recovery report
generate_recovery_report() {
    local report_file="$PROJECT_ROOT/work-recovery-report.json"
    local current_time
    current_time=$(get_timestamp)
    
    info "Generating recovery report..."
    
    # Count various states
    local total_claims=0
    local active_claims=0
    local orphaned_claims=0
    local recovered_claims=0
    
    if [ -d "$WORK_CLAIMS_DIR" ]; then
        total_claims=$(find "$WORK_CLAIMS_DIR" -name "*.json" | wc -l)
        active_claims=$(find "$WORK_CLAIMS_DIR" -name "*.json" -exec grep -l '"status":"in_progress"' {} \; 2>/dev/null | wc -l)
        orphaned_claims=$(find "$WORK_CLAIMS_DIR/orphaned" -name "*.json" 2>/dev/null | wc -l)
        recovered_claims=$(find "$WORK_CLAIMS_DIR" -name "*.recovery.json" 2>/dev/null | wc -l)
    fi
    
    # Create report
    cat > "$report_file" <<EOF
{
    "report_time": "$current_time",
    "system_status": {
        "redis_available": $(check_redis_available && echo "true" || echo "false"),
        "work_claims_dir": "$WORK_CLAIMS_DIR",
        "recovery_log": "$RECOVERY_LOG"
    },
    "work_statistics": {
        "total_claims": $total_claims,
        "active_claims": $active_claims,
        "orphaned_claims": $orphaned_claims,
        "recovered_claims": $recovered_claims
    },
    "thresholds": {
        "claim_ttl_seconds": $CLAIM_TTL,
        "stale_threshold_seconds": $STALE_THRESHOLD,
        "orphan_threshold_seconds": $ORPHAN_THRESHOLD,
        "early_failure_window_seconds": $EARLY_FAILURE_WINDOW
    }
}
EOF
    
    log "Recovery report generated: $report_file"
    cat "$report_file"
}

# Run full recovery cycle
run_recovery_cycle() {
    log "Starting work recovery cycle..."
    
    init_recovery_system
    detect_redis_orphans
    detect_file_orphans
    check_stale_heartbeats
    generate_recovery_report
    
    log "Work recovery cycle completed"
}

# Monitor mode - run recovery continuously
monitor_mode() {
    local interval=${1:-300}  # Default 5 minutes
    
    log "Starting work recovery monitor (interval: ${interval}s)"
    
    while true; do
        run_recovery_cycle
        log "Sleeping for ${interval} seconds..."
        sleep "$interval"
    done
}

# CLI interface
main() {
    case "${1:-cycle}" in
        "cycle"|"run")
            run_recovery_cycle
            ;;
        "monitor")
            monitor_mode "${2:-300}"
            ;;
        "redis-orphans")
            init_recovery_system
            detect_redis_orphans
            ;;
        "file-orphans")
            init_recovery_system
            detect_file_orphans
            ;;
        "stale-heartbeats")
            init_recovery_system
            check_stale_heartbeats
            ;;
        "report")
            init_recovery_system
            generate_recovery_report
            ;;
        "help"|"-h"|"--help")
            echo "Claude Workflow Framework Work Recovery System"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  cycle, run         Run complete recovery cycle (default)"
            echo "  monitor [interval] Run continuous monitoring (default interval: 300s)"
            echo "  redis-orphans      Check only Redis-based orphans"
            echo "  file-orphans       Check only file-based orphans"
            echo "  stale-heartbeats   Check only stale heartbeats"
            echo "  report             Generate recovery status report"
            echo "  help               Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  REDIS_URL          Redis connection URL (default: redis://localhost:6379)"
            echo ""
            echo "Examples:"
            echo "  $0                        # Run single recovery cycle"
            echo "  $0 monitor 600            # Monitor with 10-minute intervals"
            echo "  REDIS_URL=redis://custom:6379 $0 cycle"
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