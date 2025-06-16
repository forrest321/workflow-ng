#!/usr/bin/env bash
# Service Dependency Manager for Claude Workflow Framework
# Handles Redis and Docker startup detection and auto-start functionality

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REDIS_PORT=6379
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.coordination.yml"
SERVICE_CHECK_TIMEOUT=30
MAX_STARTUP_ATTEMPTS=3

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

# Check if Redis is running and accessible
check_redis_status() {
    local redis_url="${1:-redis://localhost:$REDIS_PORT}"
    
    # Try to ping Redis
    if command -v redis-cli >/dev/null 2>&1; then
        if redis-cli -u "$redis_url" ping >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    # Alternative check using netcat if redis-cli not available
    if command -v nc >/dev/null 2>&1; then
        if nc -z localhost "$REDIS_PORT" >/dev/null 2>&1; then
            # Try a simple command to verify it's actually Redis
            if echo "PING" | nc localhost "$REDIS_PORT" | grep -q "PONG"; then
                return 0
            fi
        fi
    fi
    
    return 1
}

# Check if Docker daemon is running
check_docker_status() {
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Check if docker-compose is available
check_docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
        return 0
    elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        echo "docker compose"
        return 0
    fi
    return 1
}

# Start Docker daemon (platform-specific)
start_docker_daemon() {
    local platform
    platform=$(uname -s)
    
    case "$platform" in
        Darwin*)
            info "Starting Docker Desktop on macOS..."
            if [ -d "/Applications/Docker.app" ]; then
                open -a Docker
                info "Docker Desktop starting... waiting for daemon"
                # Wait for Docker daemon to be ready
                local attempts=0
                while [ $attempts -lt $SERVICE_CHECK_TIMEOUT ]; do
                    if check_docker_status; then
                        log "Docker daemon is ready"
                        return 0
                    fi
                    sleep 2
                    ((attempts++))
                done
                error "Docker daemon failed to start within timeout"
                return 1
            else
                error "Docker Desktop not found in /Applications/"
                return 1
            fi
            ;;
        Linux*)
            info "Starting Docker daemon on Linux..."
            if command -v systemctl >/dev/null 2>&1; then
                if systemctl start docker 2>/dev/null; then
                    log "Docker daemon started via systemctl"
                    return 0
                fi
            fi
            if command -v service >/dev/null 2>&1; then
                if service docker start 2>/dev/null; then
                    log "Docker daemon started via service command"
                    return 0
                fi
            fi
            error "Failed to start Docker daemon. Please start manually:"
            error "  sudo systemctl start docker"
            error "  OR: sudo service docker start"
            return 1
            ;;
        *)
            error "Unsupported platform: $platform"
            error "Please start Docker daemon manually"
            return 1
            ;;
    esac
}

# Start Redis coordination services
start_redis_coordination() {
    local compose_cmd
    
    if ! compose_cmd=$(check_docker_compose); then
        error "docker-compose not available. Please install Docker Compose."
        return 1
    fi
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        error "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
        error "Please run the installation script first."
        return 1
    fi
    
    info "Starting Redis coordination services..."
    cd "$PROJECT_ROOT"
    
    case "$compose_cmd" in
        "docker-compose")
            if docker-compose -f docker-compose.coordination.yml up -d; then
                log "Redis coordination services started"
                return 0
            fi
            ;;
        "docker compose")
            if docker compose -f docker-compose.coordination.yml up -d; then
                log "Redis coordination services started"
                return 0
            fi
            ;;
    esac
    
    error "Failed to start Redis coordination services"
    return 1
}

# Wait for Redis to be ready after startup
wait_for_redis() {
    local redis_url="${1:-redis://localhost:$REDIS_PORT}"
    local attempts=0
    
    info "Waiting for Redis to be ready..."
    while [ $attempts -lt $SERVICE_CHECK_TIMEOUT ]; do
        if check_redis_status "$redis_url"; then
            log "Redis is ready and responding"
            return 0
        fi
        sleep 2
        ((attempts++))
    done
    
    error "Redis failed to become ready within timeout"
    return 1
}

# Main service management function
ensure_services_running() {
    local redis_url="${1:-redis://localhost:$REDIS_PORT}"
    local auto_start="${2:-true}"
    local allow_fallback="${3:-false}"
    local startup_attempts=0
    
    info "Checking service dependencies..."
    
    # Check if Redis is already running
    if check_redis_status "$redis_url"; then
        log "Redis coordination service is running"
        return 0
    fi
    
    warn "Redis coordination service not accessible"
    
    if [ "$auto_start" != "true" ]; then
        error "Auto-start disabled. Please start services manually:"
        error "  cd $PROJECT_ROOT"
        error "  docker-compose -f docker-compose.coordination.yml up -d"
        return 1
    fi
    
    # Attempt to start services
    while [ $startup_attempts -lt $MAX_STARTUP_ATTEMPTS ]; do
        info "Attempting to start services (attempt $((startup_attempts + 1))/$MAX_STARTUP_ATTEMPTS)..."
        
        # Check Docker daemon
        if ! check_docker_status; then
            warn "Docker daemon not running, attempting to start..."
            if ! start_docker_daemon; then
                error "Failed to start Docker daemon"
                ((startup_attempts++))
                continue
            fi
        fi
        
        # Start Redis coordination
        if start_redis_coordination; then
            if wait_for_redis "$redis_url"; then
                log "All services are now running"
                return 0
            fi
        fi
        
        ((startup_attempts++))
        if [ $startup_attempts -lt $MAX_STARTUP_ATTEMPTS ]; then
            warn "Startup attempt failed, retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    error "Failed to start services after $MAX_STARTUP_ATTEMPTS attempts"
    error ""
    
    # Offer fallback option with user confirmation
    if [ "$allow_fallback" = "true" ]; then
        warn "Redis coordination services are unavailable."
        warn "The workflow can fall back to file-based coordination, but this:"
        warn "  - Reduces coordination efficiency"
        warn "  - May lead to race conditions with multiple workers"
        warn "  - Lacks real-time work distribution"
        echo ""
        
        if [ -t 0 ]; then  # Only prompt if running interactively
            read -p "Continue with file-based coordination? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                warn "Proceeding with file-based coordination"
                return 2  # Special return code for fallback mode
            fi
        fi
    fi
    
    error "Manual intervention required:"
    error "1. Ensure Docker is installed and running:"
    error "   - macOS: Start Docker Desktop"
    error "   - Linux: sudo systemctl start docker"
    error ""
    error "2. Start Redis coordination services:"
    error "   cd $PROJECT_ROOT"
    error "   docker-compose -f docker-compose.coordination.yml up -d"
    error ""
    error "3. Verify Redis is accessible:"
    error "   redis-cli ping"
    error ""
    error "Alternatively, restart with fallback option:"
    error "   $0 start $redis_url true true"
    
    return 1
}

# Health check function for ongoing monitoring
health_check() {
    local redis_url="${1:-redis://localhost:$REDIS_PORT}"
    local issues_found=0
    
    # Check Redis
    if ! check_redis_status "$redis_url"; then
        error "Redis coordination service is not responding"
        ((issues_found++))
    fi
    
    # Check Docker daemon
    if ! check_docker_status; then
        error "Docker daemon is not running"
        ((issues_found++))
    fi
    
    if [ $issues_found -eq 0 ]; then
        log "All services are healthy"
        return 0
    else
        error "Found $issues_found service issues"
        return 1
    fi
}

# Stop coordination services
stop_services() {
    local compose_cmd
    
    if ! compose_cmd=$(check_docker_compose); then
        warn "docker-compose not available, cannot stop services cleanly"
        return 1
    fi
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        warn "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
        return 1
    fi
    
    info "Stopping Redis coordination services..."
    cd "$PROJECT_ROOT"
    
    case "$compose_cmd" in
        "docker-compose")
            docker-compose -f docker-compose.coordination.yml down
            ;;
        "docker compose")
            docker compose -f docker-compose.coordination.yml down
            ;;
    esac
    
    log "Coordination services stopped"
}

# CLI interface
main() {
    case "${1:-check}" in
        "start"|"ensure")
            local result
            ensure_services_running "${2:-redis://localhost:$REDIS_PORT}" "${3:-true}" "${4:-false}"
            result=$?
            case $result in
                0) log "Redis coordination services are ready" ;;
                1) error "Failed to start coordination services"; exit 1 ;;
                2) warn "Operating in file-based coordination mode"; exit 2 ;;
            esac
            ;;
        "start-with-fallback")
            local result
            ensure_services_running "${2:-redis://localhost:$REDIS_PORT}" "${3:-true}" "true"
            result=$?
            case $result in
                0) log "Redis coordination services are ready" ;;
                1) error "Failed to start coordination services"; exit 1 ;;
                2) warn "Operating in file-based coordination mode"; exit 2 ;;
            esac
            ;;
        "stop")
            stop_services
            ;;
        "check"|"health")
            health_check "${2:-redis://localhost:$REDIS_PORT}"
            ;;
        "redis-status")
            if check_redis_status "${2:-redis://localhost:$REDIS_PORT}"; then
                echo "Redis is running"
                exit 0
            else
                echo "Redis is not accessible"
                exit 1
            fi
            ;;
        "docker-status")
            if check_docker_status; then
                echo "Docker daemon is running"
                exit 0
            else
                echo "Docker daemon is not running"
                exit 1
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Claude Workflow Framework Service Manager"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  start, ensure           Start services if not running (default: auto-start enabled)"
            echo "  start-with-fallback     Start services with file-based fallback option"
            echo "  stop                    Stop coordination services"
            echo "  check, health           Check service health status"
            echo "  redis-status            Check only Redis status"
            echo "  docker-status           Check only Docker daemon status"
            echo "  help                    Show this help message"
            echo ""
            echo "Options:"
            echo "  [redis-url]             Redis connection URL (default: redis://localhost:6379)"
            echo "  [auto-start]            Enable auto-start (true/false, default: true)"
            echo "  [allow-fallback]        Allow file-based fallback with user prompt (true/false, default: false)"
            echo ""
            echo "Return Codes:"
            echo "  0 - Redis coordination available"
            echo "  1 - Failed to start services"
            echo "  2 - Operating in file-based fallback mode"
            echo ""
            echo "Examples:"
            echo "  $0 start                                           # Start with defaults (no fallback)"
            echo "  $0 start-with-fallback                             # Start with fallback option"
            echo "  $0 start redis://localhost:6379 false             # Check only, no auto-start"
            echo "  $0 start redis://localhost:6379 true true         # Enable fallback explicitly"
            echo "  $0 health redis://custom-host:6379                # Health check custom Redis"
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