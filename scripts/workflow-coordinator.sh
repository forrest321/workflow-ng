#!/usr/bin/env bash
# Claude Workflow Coordinator - Main coordination script
# Integrates service management, work recovery, and workflow coordination

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REDIS_URL="${REDIS_URL:-redis://localhost:6379}"
COORDINATOR_PID_FILE="$PROJECT_ROOT/.workflow-coordinator.pid"
RECOVERY_INTERVAL="${RECOVERY_INTERVAL:-300}"  # 5 minutes

# Expert Knowledge Base Configuration
EXPERT_SYSTEM_URL="${EXPERT_SYSTEM_URL:-http://localhost:8080}"
EXPERT_SYSTEM_ENABLED="${EXPERT_SYSTEM_ENABLED:-true}"

# Import enhanced file operations
source "$SCRIPT_DIR/workflow-file-ops.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

# Expert Knowledge Base functions
check_expert_system() {
    if [ "$EXPERT_SYSTEM_ENABLED" != "true" ]; then
        return 1
    fi
    
    local health_response
    health_response=$(curl -s --connect-timeout 5 "$EXPERT_SYSTEM_URL/health" 2>/dev/null) || return 1
    
    if echo "$health_response" | grep -q '"status":"healthy"'; then
        return 0
    else
        return 1
    fi
}

query_expert_system() {
    local query="$1"
    local domain="${2:-}"
    local top_k="${3:-5}"
    
    if ! check_expert_system; then
        warn "Expert system unavailable - proceeding without knowledge base"
        return 1
    fi
    
    local payload
    if [ -n "$domain" ]; then
        payload=$(cat <<EOF
{
    "query": "$query",
    "top_k": $top_k,
    "filters": {
        "expert": "$domain"
    }
}
EOF
        )
    else
        payload=$(cat <<EOF
{
    "query": "$query",
    "top_k": $top_k
}
EOF
        )
    fi
    
    curl -s -X POST "$EXPERT_SYSTEM_URL/api/v1/search" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null || return 1
}

get_coordination_guidance() {
    local task_type="$1"
    local technology="${2:-}"
    
    local query="best practices for $task_type coordination workflow automation"
    if [ -n "$technology" ]; then
        query="$query with $technology"
    fi
    
    info "Consulting Expert Knowledge Base for coordination guidance..."
    local guidance
    guidance=$(query_expert_system "$query" "project-management-expert" 3)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        log "Expert guidance obtained for $task_type coordination"
        echo "$guidance" | jq -r '.results[]?.content' 2>/dev/null | head -n 5
    else
        warn "No expert guidance available for $task_type"
    fi
}

get_technology_best_practices() {
    local technology="$1"
    local context="${2:-development}"
    
    local query="$technology $context best practices patterns optimization"
    
    info "Querying Expert Knowledge Base for $technology best practices..."
    local practices
    practices=$(query_expert_system "$query" "" 5)
    
    if [ $? -eq 0 ] && [ -n "$practices" ]; then
        log "Technology best practices retrieved for $technology"
        echo "$practices" | jq -r '.results[]?.content' 2>/dev/null | head -n 5
    else
        warn "No expert practices found for $technology"
    fi
}

# Check if coordinator is already running
check_coordinator_running() {
    if [ -f "$COORDINATOR_PID_FILE" ]; then
        local pid
        pid=$(cat "$COORDINATOR_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            # Stale PID file
            rm -f "$COORDINATOR_PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Initialize workflow coordination
init_coordinator() {
    log "Initializing Claude Workflow Coordinator..."
    
    # Ensure required directories exist
    mkdir -p \
        "$PROJECT_ROOT/work-claims" \
        "$PROJECT_ROOT/tasks" \
        "$PROJECT_ROOT/logs" \
        "$PROJECT_ROOT/work-claims/orphaned"
    
    # Check if already running
    if check_coordinator_running; then
        warn "Workflow coordinator already running (PID: $(cat "$COORDINATOR_PID_FILE"))"
        return 1
    fi
    
    # Store our PID
    echo $$ > "$COORDINATOR_PID_FILE"
    
    log "Workflow coordinator initialized"
    return 0
}

# Ensure services are running
ensure_services() {
    local allow_fallback="${1:-false}"
    info "Ensuring coordination services are running..."
    
    local result
    if [ "$allow_fallback" = "true" ]; then
        "$SCRIPT_DIR/service-manager.sh" start-with-fallback "$REDIS_URL"
    else
        "$SCRIPT_DIR/service-manager.sh" start "$REDIS_URL"
    fi
    result=$?
    
    case $result in
        0)
            log "Redis coordination services are running"
            return 0
            ;;
        1)
            error "Failed to ensure coordination services are running"
            return 1
            ;;
        2)
            warn "Operating in file-based coordination mode"
            warn "Redis coordination is unavailable - functionality will be limited"
            return 2
            ;;
    esac
}

# Start work recovery monitoring
start_recovery_monitoring() {
    info "Starting work recovery monitoring..."
    
    # Start recovery monitor in background
    "$SCRIPT_DIR/work-recovery.sh" monitor "$RECOVERY_INTERVAL" &
    local recovery_pid=$!
    
    # Store recovery monitor PID for cleanup
    echo "$recovery_pid" > "$PROJECT_ROOT/.recovery-monitor.pid"
    
    log "Work recovery monitoring started (PID: $recovery_pid)"
    return 0
}

# Perform initial work recovery
initial_recovery() {
    info "Performing initial work recovery scan..."
    
    if "$SCRIPT_DIR/work-recovery.sh" cycle; then
        log "Initial work recovery completed"
    else
        warn "Initial work recovery encountered issues"
    fi
}

# Health check for all components
health_check() {
    local issues=0
    
    info "Performing health check..."
    
    # Check services
    if ! "$SCRIPT_DIR/service-manager.sh" health "$REDIS_URL"; then
        error "Service health check failed"
        ((issues++))
    fi
    
    # Check work recovery system
    if ! "$SCRIPT_DIR/work-recovery.sh" report >/dev/null; then
        error "Work recovery system health check failed"
        ((issues++))
    fi
    
    # Check coordinator status
    if ! check_coordinator_running; then
        error "Workflow coordinator not running"
        ((issues++))
    fi
    
    # Check Expert Knowledge Base system
    if [ "$EXPERT_SYSTEM_ENABLED" = "true" ]; then
        if check_expert_system; then
            log "Expert Knowledge Base: Available"
        else
            warn "Expert Knowledge Base: Unavailable (continuing without expert guidance)"
        fi
    else
        info "Expert Knowledge Base: Disabled"
    fi
    
    if [ $issues -eq 0 ]; then
        log "All components healthy"
        return 0
    else
        error "Found $issues health issues"
        return 1
    fi
}

# Stop coordinator and cleanup
stop_coordinator() {
    info "Stopping workflow coordinator..."
    
    # Stop recovery monitor if running
    if [ -f "$PROJECT_ROOT/.recovery-monitor.pid" ]; then
        local recovery_pid
        recovery_pid=$(cat "$PROJECT_ROOT/.recovery-monitor.pid")
        if kill -0 "$recovery_pid" 2>/dev/null; then
            kill "$recovery_pid"
            log "Recovery monitor stopped"
        fi
        rm -f "$PROJECT_ROOT/.recovery-monitor.pid"
    fi
    
    # Clean up coordinator PID
    rm -f "$COORDINATOR_PID_FILE"
    
    log "Workflow coordinator stopped"
}

# Run coordinator in daemon mode
run_daemon() {
    local allow_fallback="${1:-false}"
    
    if ! init_coordinator; then
        exit 1
    fi
    
    # Set up cleanup on exit
    trap stop_coordinator EXIT INT TERM
    
    local service_result
    ensure_services "$allow_fallback"
    service_result=$?
    
    case $service_result in
        0)
            log "Redis coordination mode active"
            log "Enhanced file building with Redis buffers enabled"
            ;;
        1)
            error "Failed to start required services"
            exit 1
            ;;
        2)
            warn "File-based coordination mode active"
            warn "Limited functionality - using direct file I/O operations"
            warn "Redis-enhanced file building disabled"
            ;;
    esac
    
    initial_recovery
    start_recovery_monitoring
    
    log "Workflow coordinator running in daemon mode"
    log "Press Ctrl+C to stop..."
    
    # Main coordination loop
    while true; do
        # Periodic health checks
        if ! health_check; then
            warn "Health check failed, attempting recovery..."
            
            # Try to restart services (without fallback in recovery mode)
            local recovery_result
            ensure_services "false"
            recovery_result=$?
            
            if [ $recovery_result -eq 0 ]; then
                log "Services recovered"
            else
                error "Service recovery failed"
            fi
        fi
        
        # Sleep for a while before next check
        sleep 60
    done
}

# Run coordinator with fallback option
run_daemon_with_fallback() {
    run_daemon "true"
}

# Start services only (no daemon)
start_services_only() {
    log "Starting coordination services..."
    
    if ensure_services; then
        log "Coordination services started successfully"
        log "Redis URL: $REDIS_URL"
        log "To test connection: redis-cli -u $REDIS_URL ping"
    else
        error "Failed to start coordination services"
        exit 1
    fi
}

# Stop coordination services
stop_services() {
    info "Stopping coordination services..."
    
    if "$SCRIPT_DIR/service-manager.sh" stop; then
        log "Coordination services stopped"
    else
        warn "Failed to stop some services"
    fi
}

# Show coordinator status
show_status() {
    echo "Claude Workflow Coordinator Status"
    echo "=================================="
    echo
    
    # Coordinator status
    if check_coordinator_running; then
        echo -e "${GREEN}✓${NC} Coordinator: Running (PID: $(cat "$COORDINATOR_PID_FILE"))"
    else
        echo -e "${RED}✗${NC} Coordinator: Not running"
    fi
    
    # Services status
    if "$SCRIPT_DIR/service-manager.sh" health "$REDIS_URL" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Services: Healthy"
    else
        echo -e "${RED}✗${NC} Services: Issues detected"
    fi
    
    # Recovery monitor status
    if [ -f "$PROJECT_ROOT/.recovery-monitor.pid" ]; then
        local recovery_pid
        recovery_pid=$(cat "$PROJECT_ROOT/.recovery-monitor.pid")
        if kill -0 "$recovery_pid" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Recovery Monitor: Running (PID: $recovery_pid)"
        else
            echo -e "${YELLOW}⚠${NC} Recovery Monitor: PID file exists but process not running"
        fi
    else
        echo -e "${RED}✗${NC} Recovery Monitor: Not running"
    fi
    
    echo
    echo "Configuration:"
    echo "  Redis URL: $REDIS_URL"
    echo "  Recovery Interval: ${RECOVERY_INTERVAL}s"
    echo "  Project Root: $PROJECT_ROOT"
}

# Main CLI interface
main() {
    case "${1:-help}" in
        "start"|"daemon")
            run_daemon
            ;;
        "start-with-fallback"|"daemon-with-fallback")
            run_daemon_with_fallback
            ;;
        "start-services")
            start_services_only
            ;;
        "stop")
            stop_coordinator
            ;;
        "stop-services")
            stop_services
            ;;
        "restart")
            if check_coordinator_running; then
                stop_coordinator
                sleep 2
            fi
            run_daemon
            ;;
        "restart-with-fallback")
            if check_coordinator_running; then
                stop_coordinator
                sleep 2
            fi
            run_daemon_with_fallback
            ;;
        "status")
            show_status
            ;;
        "health")
            health_check
            ;;
        "recover")
            "$SCRIPT_DIR/work-recovery.sh" cycle
            ;;
        "file-buffers")
            "$SCRIPT_DIR/redis-file-builder.sh" list
            ;;
        "cleanup-buffers")
            "$SCRIPT_DIR/redis-file-builder.sh" cleanup
            ;;
        "test-file-ops")
            "$SCRIPT_DIR/workflow-file-ops.sh" test
            ;;
        "query-expert")
            local query="${2:-}"
            local domain="${3:-}"
            if [ -z "$query" ]; then
                error "Query required. Usage: $0 query-expert \"query text\" [domain]"
                exit 1
            fi
            query_expert_system "$query" "$domain" 5 | jq '.' 2>/dev/null || echo "Query failed or no results found"
            ;;
        "get-guidance")
            local task_type="${2:-deployment}"
            local technology="${3:-}"
            get_coordination_guidance "$task_type" "$technology"
            ;;
        "get-practices")
            local technology="${2:-}"
            if [ -z "$technology" ]; then
                error "Technology required. Usage: $0 get-practices \"technology\""
                exit 1
            fi
            get_technology_best_practices "$technology"
            ;;
        "expert-status")
            if check_expert_system; then
                echo -e "${GREEN}✓${NC} Expert Knowledge Base: Available"
                curl -s "$EXPERT_SYSTEM_URL/api/v1/index/stats" | jq '.' 2>/dev/null || echo "Stats unavailable"
            else
                echo -e "${RED}✗${NC} Expert Knowledge Base: Unavailable"
                echo "URL: $EXPERT_SYSTEM_URL"
                echo "Enabled: $EXPERT_SYSTEM_ENABLED"
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Claude Workflow Coordinator with Expert Knowledge Base Integration"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Core Coordination Commands:"
            echo "  start, daemon              Start coordinator in daemon mode (Redis required)"
            echo "  start-with-fallback        Start coordinator with file-based fallback option"
            echo "  daemon-with-fallback       Alias for start-with-fallback"
            echo "  start-services             Start only coordination services"
            echo "  stop                       Stop coordinator and cleanup"
            echo "  stop-services              Stop coordination services"
            echo "  restart                    Restart coordinator (Redis required)"
            echo "  restart-with-fallback      Restart coordinator with fallback option"
            echo "  status                     Show system status"
            echo "  health                     Run health check"
            echo "  recover                    Run work recovery cycle"
            echo "  file-buffers               List active Redis file buffers"
            echo "  cleanup-buffers            Clean up stale Redis file buffers"
            echo "  test-file-ops              Test Redis-enhanced file operations"
            echo ""
            echo "Expert Knowledge Base Commands:"
            echo "  query-expert \"query\" [domain]    Query Expert Knowledge Base"
            echo "  get-guidance <task-type> [tech]   Get coordination guidance"
            echo "  get-practices <technology>        Get technology best practices"
            echo "  expert-status                     Check Expert Knowledge Base status"
            echo ""
            echo "Coordination Modes:"
            echo "  Redis Mode:                Full coordination with real-time work distribution"
            echo "                             + Enhanced file building with Redis buffers"
            echo "                             + Expert Knowledge Base integration"
            echo "  File-based Fallback:       Limited coordination with direct file I/O"
            echo "                             + Expert guidance when available"
            echo ""
            echo "Environment Variables:"
            echo "  REDIS_URL                  Redis connection URL (default: redis://localhost:6379)"
            echo "  RECOVERY_INTERVAL          Work recovery interval in seconds (default: 300)"
            echo "  EXPERT_SYSTEM_URL          Expert Knowledge Base URL (default: http://localhost:8080)"
            echo "  EXPERT_SYSTEM_ENABLED      Enable Expert Knowledge Base (default: true)"
            echo ""
            echo "Examples:"
            echo "  $0                                            # Start coordinator (Redis required)"
            echo "  $0 start-with-fallback                        # Start with fallback option"
            echo "  $0 query-expert \"Go error handling\" go-expert  # Query expert system"
            echo "  $0 get-guidance deployment docker            # Get deployment guidance"
            echo "  $0 get-practices flutter                     # Get Flutter best practices"
            echo "  $0 expert-status                             # Check expert system status"
            echo "  EXPERT_SYSTEM_ENABLED=false $0 start         # Disable expert system"
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