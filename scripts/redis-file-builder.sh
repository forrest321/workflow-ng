#!/usr/bin/env bash
# Redis-based File Building System for Claude Workflow Framework
# Builds files in Redis memory before committing to disk to eliminate I/O bottlenecks

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REDIS_URL="${REDIS_URL:-redis://localhost:6379}"
FILE_BUFFER_PREFIX="file:buffer:"
FILE_LOCK_PREFIX="file:lock:"
FILE_METADATA_PREFIX="file:meta:"
LOCK_TTL=300  # 5 minutes
BUFFER_TTL=3600  # 1 hour

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

# Check if Redis is available
check_redis_available() {
    if command -v redis-cli >/dev/null 2>&1; then
        redis-cli -u "$REDIS_URL" ping >/dev/null 2>&1
    else
        return 1
    fi
}

# Generate unique session ID
generate_session_id() {
    echo "session_$(date +%s)_$$_$(openssl rand -hex 4 2>/dev/null || echo $RANDOM)"
}

# Get current timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Acquire file lock for editing
acquire_file_lock() {
    local file_path="$1"
    local session_id="$2"
    local lock_key="${FILE_LOCK_PREFIX}${file_path}"
    
    # Try to acquire lock with TTL
    local result
    result=$(redis-cli -u "$REDIS_URL" SET "$lock_key" "$session_id" EX $LOCK_TTL NX 2>/dev/null)
    
    if [ "$result" = "OK" ]; then
        log "File lock acquired: $file_path (session: $session_id)"
        return 0
    else
        # Check if we already own the lock
        local current_owner
        current_owner=$(redis-cli -u "$REDIS_URL" GET "$lock_key" 2>/dev/null)
        if [ "$current_owner" = "$session_id" ]; then
            # Refresh the lock TTL
            redis-cli -u "$REDIS_URL" EXPIRE "$lock_key" $LOCK_TTL >/dev/null 2>&1
            return 0
        fi
        warn "File lock unavailable: $file_path (owned by: $current_owner)"
        return 1
    fi
}

# Release file lock
release_file_lock() {
    local file_path="$1"
    local session_id="$2"
    local lock_key="${FILE_LOCK_PREFIX}${file_path}"
    
    # Use Lua script to safely release only our lock
    local lua_script='
    if redis.call("GET", KEYS[1]) == ARGV[1] then
        return redis.call("DEL", KEYS[1])
    else
        return 0
    end'
    
    local result
    result=$(redis-cli -u "$REDIS_URL" EVAL "$lua_script" 1 "$lock_key" "$session_id" 2>/dev/null)
    
    if [ "$result" = "1" ]; then
        log "File lock released: $file_path"
        return 0
    else
        warn "Failed to release file lock (not owned): $file_path"
        return 1
    fi
}

# Initialize file buffer from existing file or create empty
init_file_buffer() {
    local file_path="$1"
    local session_id="$2"
    local buffer_key="${FILE_BUFFER_PREFIX}${session_id}:${file_path}"
    local meta_key="${FILE_METADATA_PREFIX}${session_id}:${file_path}"
    
    # Store metadata
    local metadata
    metadata=$(cat <<EOF
{
    "file_path": "$file_path",
    "session_id": "$session_id",
    "created_at": "$(get_timestamp)",
    "last_modified": "$(get_timestamp)",
    "lock_acquired": true,
    "committed": false
}
EOF
)
    
    redis-cli -u "$REDIS_URL" SET "$meta_key" "$metadata" EX $BUFFER_TTL >/dev/null 2>&1
    
    # Load existing file content if it exists
    if [ -f "$file_path" ]; then
        info "Loading existing file into buffer: $file_path"
        # Use base64 encoding to safely handle binary content and special characters
        base64 "$file_path" | redis-cli -u "$REDIS_URL" -x SET "$buffer_key" >/dev/null 2>&1
        redis-cli -u "$REDIS_URL" EXPIRE "$buffer_key" $BUFFER_TTL >/dev/null 2>&1
        
        # Mark as base64 encoded in metadata
        metadata=$(echo "$metadata" | jq '. + {"encoding": "base64"}')
        redis-cli -u "$REDIS_URL" SET "$meta_key" "$metadata" EX $BUFFER_TTL >/dev/null 2>&1
    else
        info "Creating new file buffer: $file_path"
        # Empty file - just set empty string
        redis-cli -u "$REDIS_URL" SET "$buffer_key" "" EX $BUFFER_TTL >/dev/null 2>&1
        
        # Mark as plain text
        metadata=$(echo "$metadata" | jq '. + {"encoding": "plain"}')
        redis-cli -u "$REDIS_URL" SET "$meta_key" "$metadata" EX $BUFFER_TTL >/dev/null 2>&1
    fi
    
    log "File buffer initialized: $file_path"
    echo "$buffer_key"
}

# Append content to file buffer
append_to_buffer() {
    local buffer_key="$1"
    local content="$2"
    local session_id="$3"
    local file_path="$4"
    local meta_key="${FILE_METADATA_PREFIX}${session_id}:${file_path}"
    
    # Get current encoding
    local encoding
    encoding=$(redis-cli -u "$REDIS_URL" GET "$meta_key" 2>/dev/null | jq -r '.encoding // "plain"')
    
    if [ "$encoding" = "base64" ]; then
        # Convert content to base64 and append
        local encoded_content
        encoded_content=$(echo -n "$content" | base64 -w 0)
        redis-cli -u "$REDIS_URL" APPEND "$buffer_key" "$encoded_content" >/dev/null 2>&1
    else
        # Direct append for plain text
        redis-cli -u "$REDIS_URL" APPEND "$buffer_key" "$content" >/dev/null 2>&1
    fi
    
    # Update metadata timestamp
    local updated_meta
    updated_meta=$(redis-cli -u "$REDIS_URL" GET "$meta_key" 2>/dev/null | jq '. + {"last_modified": "'$(get_timestamp)'"}')
    redis-cli -u "$REDIS_URL" SET "$meta_key" "$updated_meta" EX $BUFFER_TTL >/dev/null 2>&1
    
    # Refresh buffer TTL
    redis-cli -u "$REDIS_URL" EXPIRE "$buffer_key" $BUFFER_TTL >/dev/null 2>&1
}

# Replace content in file buffer using Redis string operations
replace_in_buffer() {
    local buffer_key="$1"
    local old_pattern="$2"
    local new_content="$3"
    local session_id="$4"
    local file_path="$5"
    local meta_key="${FILE_METADATA_PREFIX}${session_id}:${file_path}"
    
    # Get current content
    local current_content
    current_content=$(redis-cli -u "$REDIS_URL" GET "$buffer_key" 2>/dev/null)
    
    # Get encoding
    local encoding
    encoding=$(redis-cli -u "$REDIS_URL" GET "$meta_key" 2>/dev/null | jq -r '.encoding // "plain"')
    
    if [ "$encoding" = "base64" ]; then
        # Decode, replace, encode
        local decoded_content
        decoded_content=$(echo "$current_content" | base64 -d)
        local updated_content
        updated_content=$(echo "$decoded_content" | sed "s|$old_pattern|$new_content|g")
        local encoded_updated
        encoded_updated=$(echo "$updated_content" | base64 -w 0)
        redis-cli -u "$REDIS_URL" SET "$buffer_key" "$encoded_updated" EX $BUFFER_TTL >/dev/null 2>&1
    else
        # Direct string replacement using Lua script for atomicity
        local lua_script='
        local content = redis.call("GET", KEYS[1])
        if content then
            local updated = string.gsub(content, ARGV[1], ARGV[2])
            redis.call("SET", KEYS[1], updated)
            redis.call("EXPIRE", KEYS[1], ARGV[3])
            return updated
        end
        return nil'
        
        redis-cli -u "$REDIS_URL" EVAL "$lua_script" 1 "$buffer_key" "$old_pattern" "$new_content" "$BUFFER_TTL" >/dev/null 2>&1
    fi
    
    # Update metadata
    local updated_meta
    updated_meta=$(redis-cli -u "$REDIS_URL" GET "$meta_key" 2>/dev/null | jq '. + {"last_modified": "'$(get_timestamp)'"}')
    redis-cli -u "$REDIS_URL" SET "$meta_key" "$updated_meta" EX $BUFFER_TTL >/dev/null 2>&1
}

# Insert content at specific position in buffer
insert_at_position() {
    local buffer_key="$1"
    local position="$2"
    local content="$3"
    local session_id="$4"
    local file_path="$5"
    local meta_key="${FILE_METADATA_PREFIX}${session_id}:${file_path}"
    
    # Use Lua script for atomic insert operation
    local lua_script='
    local current = redis.call("GET", KEYS[1]) or ""
    local pos = tonumber(ARGV[1])
    local content = ARGV[2]
    local ttl = tonumber(ARGV[3])
    
    local before = string.sub(current, 1, pos - 1)
    local after = string.sub(current, pos)
    local updated = before .. content .. after
    
    redis.call("SET", KEYS[1], updated)
    redis.call("EXPIRE", KEYS[1], ttl)
    return updated'
    
    redis-cli -u "$REDIS_URL" EVAL "$lua_script" 1 "$buffer_key" "$position" "$content" "$BUFFER_TTL" >/dev/null 2>&1
    
    # Update metadata
    local updated_meta
    updated_meta=$(redis-cli -u "$REDIS_URL" GET "$meta_key" 2>/dev/null | jq '. + {"last_modified": "'$(get_timestamp)'"}')
    redis-cli -u "$REDIS_URL" SET "$meta_key" "$updated_meta" EX $BUFFER_TTL >/dev/null 2>&1
}

# Get buffer content for preview
get_buffer_content() {
    local buffer_key="$1"
    local session_id="$2"
    local file_path="$3"
    local meta_key="${FILE_METADATA_PREFIX}${session_id}:${file_path}"
    
    local content
    content=$(redis-cli -u "$REDIS_URL" GET "$buffer_key" 2>/dev/null)
    
    # Check encoding
    local encoding
    encoding=$(redis-cli -u "$REDIS_URL" GET "$meta_key" 2>/dev/null | jq -r '.encoding // "plain"')
    
    if [ "$encoding" = "base64" ]; then
        echo "$content" | base64 -d
    else
        echo "$content"
    fi
}

# Commit buffer to disk atomically
commit_buffer_to_disk() {
    local buffer_key="$1"
    local session_id="$2"
    local file_path="$3"
    local meta_key="${FILE_METADATA_PREFIX}${session_id}:${file_path}"
    
    info "Committing buffer to disk: $file_path"
    
    # Create directory if needed
    local dir_path
    dir_path=$(dirname "$file_path")
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
    fi
    
    # Get content and encoding
    local content
    content=$(redis-cli -u "$REDIS_URL" GET "$buffer_key" 2>/dev/null)
    local encoding
    encoding=$(redis-cli -u "$REDIS_URL" GET "$meta_key" 2>/dev/null | jq -r '.encoding // "plain"')
    
    # Create temporary file for atomic write
    local temp_file="${file_path}.tmp.$$"
    
    # Write content based on encoding
    if [ "$encoding" = "base64" ]; then
        echo "$content" | base64 -d > "$temp_file"
    else
        echo -n "$content" > "$temp_file"
    fi
    
    # Atomic move
    if mv "$temp_file" "$file_path"; then
        # Update metadata to mark as committed
        local updated_meta
        updated_meta=$(redis-cli -u "$REDIS_URL" GET "$meta_key" 2>/dev/null | jq '. + {"committed": true, "committed_at": "'$(get_timestamp)'"}')
        redis-cli -u "$REDIS_URL" SET "$meta_key" "$updated_meta" EX $BUFFER_TTL >/dev/null 2>&1
        
        log "Buffer committed to disk: $file_path"
        return 0
    else
        error "Failed to commit buffer to disk: $file_path"
        rm -f "$temp_file" 2>/dev/null || true
        return 1
    fi
}

# Clean up buffer and release locks
cleanup_buffer() {
    local buffer_key="$1"
    local session_id="$2"
    local file_path="$3"
    local meta_key="${FILE_METADATA_PREFIX}${session_id}:${file_path}"
    
    # Release file lock
    release_file_lock "$file_path" "$session_id"
    
    # Clean up Redis keys
    redis-cli -u "$REDIS_URL" DEL "$buffer_key" "$meta_key" >/dev/null 2>&1
    
    log "Buffer cleaned up: $file_path"
}

# High-level file editing workflow
edit_file_workflow() {
    local file_path="$1"
    local operation="$2"
    shift 2
    local args=("$@")
    
    if ! check_redis_available; then
        error "Redis not available - cannot use Redis-based file building"
        return 1
    fi
    
    local session_id
    session_id=$(generate_session_id)
    
    info "Starting Redis-based file editing: $file_path"
    
    # Acquire lock
    if ! acquire_file_lock "$file_path" "$session_id"; then
        error "Could not acquire file lock: $file_path"
        return 1
    fi
    
    # Initialize buffer
    local buffer_key
    buffer_key=$(init_file_buffer "$file_path" "$session_id")
    
    # Perform operation
    local result=0
    case "$operation" in
        "append")
            append_to_buffer "$buffer_key" "${args[0]}" "$session_id" "$file_path"
            ;;
        "replace")
            replace_in_buffer "$buffer_key" "${args[0]}" "${args[1]}" "$session_id" "$file_path"
            ;;
        "insert")
            insert_at_position "$buffer_key" "${args[0]}" "${args[1]}" "$session_id" "$file_path"
            ;;
        "preview")
            get_buffer_content "$buffer_key" "$session_id" "$file_path"
            cleanup_buffer "$buffer_key" "$session_id" "$file_path"
            return 0
            ;;
        *)
            error "Unknown operation: $operation"
            result=1
            ;;
    esac
    
    if [ $result -eq 0 ] && [ "$operation" != "preview" ]; then
        # Commit changes
        if commit_buffer_to_disk "$buffer_key" "$session_id" "$file_path"; then
            log "File editing completed successfully: $file_path"
        else
            error "Failed to commit changes: $file_path"
            result=1
        fi
    fi
    
    # Cleanup
    cleanup_buffer "$buffer_key" "$session_id" "$file_path"
    
    return $result
}

# List active file buffers
list_active_buffers() {
    if ! check_redis_available; then
        error "Redis not available"
        return 1
    fi
    
    info "Active file buffers:"
    local buffer_keys
    buffer_keys=$(redis-cli -u "$REDIS_URL" KEYS "${FILE_BUFFER_PREFIX}*" 2>/dev/null | tr '\n' ' ')
    
    if [ -z "$buffer_keys" ]; then
        log "No active file buffers"
        return 0
    fi
    
    for buffer_key in $buffer_keys; do
        local session_info
        session_info=$(echo "$buffer_key" | sed "s|${FILE_BUFFER_PREFIX}||" | cut -d: -f1)
        local file_path
        file_path=$(echo "$buffer_key" | sed "s|${FILE_BUFFER_PREFIX}${session_info}:||")
        
        local meta_key="${FILE_METADATA_PREFIX}${session_info}:${file_path}"
        local metadata
        metadata=$(redis-cli -u "$REDIS_URL" GET "$meta_key" 2>/dev/null)
        
        if [ -n "$metadata" ]; then
            local last_modified
            last_modified=$(echo "$metadata" | jq -r '.last_modified // "unknown"')
            local committed
            committed=$(echo "$metadata" | jq -r '.committed // false')
            
            echo "  $file_path (session: $session_info, modified: $last_modified, committed: $committed)"
        fi
    done
}

# Clean up stale buffers
cleanup_stale_buffers() {
    if ! check_redis_available; then
        error "Redis not available"
        return 1
    fi
    
    info "Cleaning up stale file buffers..."
    local cleaned=0
    
    # Clean up expired locks
    local lock_keys
    lock_keys=$(redis-cli -u "$REDIS_URL" KEYS "${FILE_LOCK_PREFIX}*" 2>/dev/null | tr '\n' ' ')
    
    for lock_key in $lock_keys; do
        # Check if lock has TTL, if not it's stale
        local ttl
        ttl=$(redis-cli -u "$REDIS_URL" TTL "$lock_key" 2>/dev/null)
        if [ "$ttl" = "-1" ]; then
            redis-cli -u "$REDIS_URL" DEL "$lock_key" >/dev/null 2>&1
            ((cleaned++))
        fi
    done
    
    log "Cleaned up $cleaned stale file buffers"
}

# CLI interface
main() {
    case "${1:-help}" in
        "edit")
            # Usage: edit <file_path> <operation> [args...]
            if [ $# -lt 3 ]; then
                error "Usage: $0 edit <file_path> <operation> [args...]"
                error "Operations: append <content>, replace <old> <new>, insert <position> <content>, preview"
                exit 1
            fi
            edit_file_workflow "$2" "$3" "${@:4}"
            ;;
        "list"|"status")
            list_active_buffers
            ;;
        "cleanup")
            cleanup_stale_buffers
            ;;
        "test")
            # Simple test workflow
            local test_file="/tmp/redis-file-test.txt"
            info "Testing Redis file building with: $test_file"
            
            edit_file_workflow "$test_file" "append" "Hello, Redis file building!\n"
            edit_file_workflow "$test_file" "append" "This is a test.\n"
            edit_file_workflow "$test_file" "replace" "test" "demonstration"
            
            info "Final content:"
            cat "$test_file"
            rm -f "$test_file"
            ;;
        "help"|"-h"|"--help")
            echo "Redis-based File Building System"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  edit <file> <op> [args]   Edit file using Redis buffers"
            echo "    Operations:"
            echo "      append <content>        Append content to file"
            echo "      replace <old> <new>     Replace text in file"
            echo "      insert <pos> <content>  Insert content at position"
            echo "      preview                 Preview current buffer content"
            echo ""
            echo "  list, status              List active file buffers"
            echo "  cleanup                   Clean up stale buffers"
            echo "  test                      Run a simple test"
            echo "  help                      Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  REDIS_URL                 Redis connection URL (default: redis://localhost:6379)"
            echo ""
            echo "Features:"
            echo "  - File locking to prevent concurrent edits"
            echo "  - In-memory editing with Redis string operations"
            echo "  - Atomic commits to disk"
            echo "  - Base64 encoding for binary files"
            echo "  - Automatic cleanup and TTL management"
            echo ""
            echo "Examples:"
            echo "  $0 edit /path/to/file.txt append 'New line\\n'"
            echo "  $0 edit /path/to/file.txt replace 'old text' 'new text'"
            echo "  $0 edit /path/to/file.txt preview"
            echo "  $0 list"
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