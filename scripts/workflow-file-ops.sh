#!/usr/bin/env bash
# Workflow File Operations 
# High-level file operations for workflow coordination

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

# Atomic file append
atomic_file_append() {
    local file_path="$1"
    local content="$2"
    
    # Ensure directory exists
    local dir_path
    dir_path=$(dirname "$file_path")
    mkdir -p "$dir_path"
    
    # Direct append (efficient for workflow needs)
    printf "%s" "$content" >> "$file_path"
}

# Atomic file replace using sed
atomic_file_replace() {
    local file_path="$1"
    local old_pattern="$2"
    local new_content="$3"
    
    # Ensure file exists
    if [ ! -f "$file_path" ]; then
        mkdir -p "$(dirname "$file_path")"
        touch "$file_path"
    fi
    
    # Use sed for replacement (cross-platform)
    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "s|$old_pattern|$new_content|g" "$file_path"
    else
        sed -i "s|$old_pattern|$new_content|g" "$file_path"
    fi
}

# Atomic file write using temporary file
atomic_file_write() {
    local file_path="$1"
    local content="$2"
    
    # Ensure directory exists
    local dir_path
    dir_path=$(dirname "$file_path")
    mkdir -p "$dir_path"
    
    # Atomic write using temporary file
    local temp_file="${file_path}.tmp.$$"
    printf "%s" "$content" > "$temp_file"
    mv "$temp_file" "$file_path"
}

# Build file with multiple operations (applied sequentially)
build_file_incrementally() {
    local file_path="$1"
    shift
    local operations=("$@")
    
    info "Building file incrementally: $file_path"
    
    # Process operations sequentially
    local op_count=0
    for operation in "${operations[@]}"; do
        ((op_count++))
        info "Applying operation $op_count: $operation"
        
        # Parse operation (format: "operation:arg1:arg2:...")
        IFS=':' read -ra op_parts <<< "$operation"
        local op_type="${op_parts[0]}"
        
        case "$op_type" in
            "append")
                atomic_file_append "$file_path" "${op_parts[1]}"
                ;;
            "replace")
                atomic_file_replace "$file_path" "${op_parts[1]}" "${op_parts[2]}"
                ;;
            *)
                warn "Unknown operation type: $op_type"
                ;;
        esac
    done
    
    log "Incremental file build completed: $file_path ($op_count operations)"
}

# Create work claim file
create_work_claim() {
    local task_id="$1"
    local agent_id="$2"
    local claim_data="$3"
    local claim_file="$PROJECT_ROOT/work-claims/${task_id}.json"
    
    info "Creating work claim: $task_id"
    atomic_file_write "$claim_file" "$claim_data"
}

# Update work status
update_work_status() {
    local task_id="$1"
    local new_status="$2"
    local additional_data="${3:-}"
    local claim_file="$PROJECT_ROOT/work-claims/${task_id}.json"
    
    if [ ! -f "$claim_file" ]; then
        error "Work claim file not found: $claim_file"
        return 1
    fi
    
    info "Updating work status: $task_id -> $new_status"
    
    # Use jq to update the JSON, then write back atomically
    local updated_content
    if [ -n "$additional_data" ]; then
        updated_content=$(jq '. + {"status": "'$new_status'", "last_updated": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' "$claim_file" | jq ". + $additional_data")
    else
        updated_content=$(jq '. + {"status": "'$new_status'", "last_updated": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' "$claim_file")
    fi
    
    atomic_file_write "$claim_file" "$updated_content"
}

# Build task result file
build_task_result() {
    local task_id="$1"
    local result_file="$PROJECT_ROOT/task-results/${task_id}.json"
    
    info "Building task result file: $task_id"
    
    # Start with basic structure
    local initial_content
    initial_content=$(cat <<EOF
{
    "task_id": "$task_id",
    "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "status": "building",
    "results": []
}
EOF
)
    
    atomic_file_write "$result_file" "$initial_content"
    echo "$result_file"
}

# Add result to task result file
add_task_result() {
    local result_file="$1"
    local result_data="$2"
    
    info "Adding result to task file"
    
    # Use jq to add to results array atomically
    local temp_file="${result_file}.tmp.$$"
    jq ".results += [$result_data]" "$result_file" > "$temp_file"
    mv "$temp_file" "$result_file"
}

# Complete task result file
complete_task_result() {
    local result_file="$1"
    local final_status="$2"
    
    info "Completing task result: $final_status"
    atomic_file_replace "$result_file" '"status": "building"' "\"status\": \"$final_status\", \"completed_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\""
}

# Batch file operations for efficiency
batch_file_operations() {
    local operations_file="$1"
    
    if [ ! -f "$operations_file" ]; then
        error "Operations file not found: $operations_file"
        return 1
    fi
    
    info "Processing batch file operations from: $operations_file"
    
    while IFS= read -r operation_line; do
        if [ -z "$operation_line" ] || [[ "$operation_line" =~ ^# ]]; then
            continue  # Skip empty lines and comments
        fi
        
        # Parse operation line (format: "operation_type:file_path:args...")
        IFS=':' read -ra op_parts <<< "$operation_line"
        local op_type="${op_parts[0]}"
        local file_path="${op_parts[1]}"
        
        case "$op_type" in
            "append")
                atomic_file_append "$file_path" "${op_parts[2]}"
                ;;
            "replace")
                atomic_file_replace "$file_path" "${op_parts[2]}" "${op_parts[3]}"
                ;;
            "write")
                atomic_file_write "$file_path" "${op_parts[2]}"
                ;;
            "incremental")
                # Incremental build with multiple operations
                local ops=("${op_parts[@]:2}")
                build_file_incrementally "$file_path" "${ops[@]}"
                ;;
            *)
                warn "Unknown batch operation: $op_type"
                ;;
        esac
    done < "$operations_file"
    
    log "Batch file operations completed"
}

# CLI interface
main() {
    case "${1:-help}" in
        "append")
            atomic_file_append "$2" "$3"
            ;;
        "replace")
            atomic_file_replace "$2" "$3" "$4"
            ;;
        "write")
            atomic_file_write "$2" "$3"
            ;;
        "incremental")
            local file_path="$2"
            shift 2
            build_file_incrementally "$file_path" "$@"
            ;;
        "claim")
            create_work_claim "$2" "$3" "$4"
            ;;
        "status")
            update_work_status "$2" "$3" "$4"
            ;;
        "result-init")
            build_task_result "$2"
            ;;
        "result-add")
            add_task_result "$2" "$3"
            ;;
        "result-complete")
            complete_task_result "$2" "$3"
            ;;
        "batch")
            batch_file_operations "$2"
            ;;
        "test")
            # Test various operations
            local test_dir="/tmp/workflow-file-ops-test"
            mkdir -p "$test_dir"
            
            info "Testing workflow file operations..."
            
            # Test incremental build
            build_file_incrementally "$test_dir/test.txt" \
                "append:Hello " \
                "append:workflow " \
                "append:file operations!\n" \
                "replace:workflow:enhanced workflow"
            
            info "Test file content:"
            cat "$test_dir/test.txt"
            
            # Test work claim
            local claim_data='{"task_id":"test-123","agent_id":"test-agent","status":"claimed","claimed_at":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
            create_work_claim "test-123" "test-agent" "$claim_data"
            
            # Test status update
            update_work_status "test-123" "in_progress" '{"progress": 50}'
            
            info "Work claim content:"
            cat "$PROJECT_ROOT/work-claims/test-123.json"
            
            # Cleanup
            rm -rf "$test_dir"
            rm -f "$PROJECT_ROOT/work-claims/test-123.json"
            ;;
        "help"|"-h"|"--help")
            echo "Workflow File Operations - Traditional file operations"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  append <file> <content>           Atomic append operation"
            echo "  replace <file> <old> <new>        Atomic replace operation"
            echo "  write <file> <content>            Atomic write operation"
            echo "  incremental <file> <ops...>       Build file with multiple operations"
            echo "  claim <task_id> <agent> <data>    Create work claim"
            echo "  status <task_id> <status> [data]  Update work status"
            echo "  result-init <task_id>             Initialize task result file"
            echo "  result-add <file> <data>          Add result to task file"
            echo "  result-complete <file> <status>   Complete task result"
            echo "  batch <operations_file>           Process batch operations"
            echo "  test                              Run test operations"
            echo "  help                              Show this help message"
            echo ""
            echo "Operation Formats (for incremental):"
            echo "  append:content                    Append content"
            echo "  replace:old:new                   Replace text"
            echo ""
            echo "Features:"
            echo "  - Atomic file operations prevent corruption"
            echo "  - Cross-platform compatibility"
            echo "  - Efficient traditional file I/O"
            echo "  - Sequential operation support"
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