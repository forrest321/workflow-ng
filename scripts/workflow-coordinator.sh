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
            ;;
        1)
            error "Failed to start required services"
            exit 1
            ;;
        2)
            warn "File-based coordination mode active"
            warn "Limited functionality - no real-time coordination available"
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
        "help"|"-h"|"--help")
            echo "Claude Workflow Coordinator"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
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
            echo "  help                       Show this help message"
            echo ""
            echo "Coordination Modes:"
            echo "  Redis Mode:                Full coordination with real-time work distribution"
            echo "  File-based Fallback:       Limited coordination, may have race conditions"
            echo ""
            echo "Environment Variables:"
            echo "  REDIS_URL                  Redis connection URL (default: redis://localhost:6379)"
            echo "  RECOVERY_INTERVAL          Work recovery interval in seconds (default: 300)"
            echo ""
            echo "Examples:"
            echo "  $0                                            # Start coordinator (Redis required)"
            echo "  $0 start-with-fallback                        # Start with fallback option"
            echo "  $0 start-services                             # Start services only"
            echo "  REDIS_URL=redis://custom:6379 $0 start       # Custom Redis URL"
            echo "  RECOVERY_INTERVAL=600 $0 daemon               # 10-minute recovery interval"
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