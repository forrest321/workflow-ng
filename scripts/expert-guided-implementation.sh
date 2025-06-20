#!/usr/bin/env bash
# Expert-Guided Implementation System
# Provides context-aware development assistance using Expert Knowledge Base

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXPERT_SYSTEM_URL="${EXPERT_SYSTEM_URL:-http://localhost:8080}"
IMPLEMENTATION_CACHE_DIR="$PROJECT_ROOT/.implementation-cache"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[IMPL]${NC} $*"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${CYAN}[SUCCESS]${NC} $*"
}

expert() {
    echo -e "${PURPLE}[EXPERT]${NC} $*"
}

# Expert system integration
check_expert_system() {
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
        warn "Expert system unavailable - proceeding without guidance"
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

# Technology detection
detect_file_technology() {
    local file_path="$1"
    local extension="${file_path##*.}"
    
    case "$extension" in
        "js"|"jsx"|"mjs"|"cjs") echo "javascript" ;;
        "ts"|"tsx") echo "typescript" ;;
        "go") echo "go" ;;
        "py") echo "python" ;;
        "rs") echo "rust" ;;
        "java") echo "java" ;;
        "rb") echo "ruby" ;;
        "php") echo "php" ;;
        "swift") echo "swift" ;;
        "kt"|"kts") echo "kotlin" ;;
        "dart") echo "dart" ;;
        "scala") echo "scala" ;;
        "hs") echo "haskell" ;;
        "ex"|"exs") echo "elixir" ;;
        "lua") echo "lua" ;;
        "sh"|"bash") echo "bash" ;;
        "sql") echo "sql" ;;
        "yml"|"yaml") echo "yaml" ;;
        "json") echo "json" ;;
        "xml") echo "xml" ;;
        "html") echo "html" ;;
        "css") echo "css" ;;
        "scss"|"sass") echo "sass" ;;
        *) echo "unknown" ;;
    esac
}

# Implementation guidance functions
get_code_implementation_guidance() {
    local task_description="$1"
    local technology="$2"
    local context="${3:-development}"
    
    expert "Consulting Expert Knowledge Base for implementation guidance..."
    
    local query="$task_description implementation example $technology $context best practices patterns"
    local domain=""
    
    # Map technology to expert domain
    case "$technology" in
        "javascript"|"typescript"|"js"|"ts") domain="javascript-expert" ;;
        "go"|"golang") domain="go-expert" ;;
        "python"|"py") domain="python-expert" ;;
        "rust"|"rs") domain="rust-expert" ;;
        "java") domain="java-expert" ;;
        "ruby"|"rb") domain="ruby-expert" ;;
        "php") domain="php-expert" ;;
        "swift") domain="swift-expert" ;;
        "kotlin"|"kt") domain="kotlin-expert" ;;
        "dart"|"flutter") domain="flutterbeam" ;;
        "scala") domain="scala-expert" ;;
        "haskell"|"hs") domain="haskell-expert" ;;
        "elixir"|"ex") domain="elixir-expert" ;;
        "lua") domain="lua-expert" ;;
        *) domain="" ;;
    esac
    
    local guidance
    guidance=$(query_expert_system "$query" "$domain" 8)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        success "Implementation guidance retrieved from Expert Knowledge Base"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 10
    else
        warn "No specific implementation guidance found"
        echo "General implementation recommendations:"
        echo "- Follow language-specific conventions"
        echo "- Implement error handling"
        echo "- Add appropriate logging"
        echo "- Consider performance implications"
        echo "- Write clean, readable code"
    fi
}

get_api_design_guidance() {
    local api_type="$1"
    local technology="$2"
    
    expert "Getting API design guidance..."
    
    local query="$api_type API design best practices $technology patterns examples"
    local domain="rest-api-expert"
    
    if [[ "$api_type" =~ [Gg]raph[Qq][Ll] ]]; then
        domain="graphql-expert"
    fi
    
    local guidance
    guidance=$(query_expert_system "$query" "$domain" 6)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        success "API design guidance retrieved"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 8
    else
        warn "No specific API design guidance found"
        echo "General API design principles:"
        echo "- Use consistent naming conventions"
        echo "- Implement proper status codes"
        echo "- Add comprehensive error handling"
        echo "- Document all endpoints"
        echo "- Version your API"
    fi
}

get_database_guidance() {
    local db_operation="$1"
    local database_type="$2"
    
    expert "Getting database guidance..."
    
    local query="$db_operation $database_type best practices optimization patterns"
    local domain=""
    
    case "$database_type" in
        "mysql"|"mariadb") domain="mysql-expert" ;;
        "postgresql"|"postgres") domain="postgresql-expert" ;;
        "sql"|"sqlite") domain="sql-expert" ;;
        "firebase"|"firestore") domain="firebase-expert" ;;
        *) domain="database-expert" ;;
    esac
    
    local guidance
    guidance=$(query_expert_system "$query" "$domain" 6)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        success "Database guidance retrieved"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 8
    else
        warn "No specific database guidance found"
        echo "General database best practices:"
        echo "- Use proper indexing"
        echo "- Implement connection pooling"
        echo "- Handle transactions correctly"
        echo "- Optimize queries"
        echo "- Plan for scalability"
    fi
}

get_security_guidance() {
    local security_context="$1"
    local technology="$2"
    
    expert "Getting security guidance..."
    
    local query="$security_context security best practices $technology vulnerabilities prevention"
    local guidance
    guidance=$(query_expert_system "$query" "security-expert" 8)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        success "Security guidance retrieved"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 10
    else
        warn "No specific security guidance found"
        echo "General security recommendations:"
        echo "- Validate all inputs"
        echo "- Use secure authentication"
        echo "- Implement proper authorization"
        echo "- Encrypt sensitive data"
        echo "- Keep dependencies updated"
    fi
}

get_performance_guidance() {
    local performance_context="$1"
    local technology="$2"
    
    expert "Getting performance optimization guidance..."
    
    local query="$performance_context performance optimization $technology patterns techniques"
    local guidance
    guidance=$(query_expert_system "$query" "" 6)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        success "Performance guidance retrieved"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 8
    else
        warn "No specific performance guidance found"
        echo "General performance recommendations:"
        echo "- Profile before optimizing"
        echo "- Cache frequently accessed data"
        echo "- Optimize database queries"
        echo "- Use appropriate data structures"
        echo "- Consider asynchronous operations"
    fi
}

analyze_code_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        error "File not found: $file_path"
        return 1
    fi
    
    local technology
    technology=$(detect_file_technology "$file_path")
    
    info "Analyzing file: $file_path (Technology: $technology)"
    
    # Basic file analysis
    local line_count
    line_count=$(wc -l < "$file_path")
    
    local complexity="Simple"
    if [ "$line_count" -gt 100 ] && [ "$line_count" -lt 500 ]; then
        complexity="Medium"
    elif [ "$line_count" -ge 500 ]; then
        complexity="Complex"
    fi
    
    echo "File Analysis:"
    echo "============="
    echo "Technology: $technology"
    echo "Lines: $line_count"
    echo "Complexity: $complexity"
    echo ""
    
    # Get technology-specific guidance
    if [ "$technology" != "unknown" ]; then
        local query="$technology code review best practices patterns $complexity"
        local guidance
        guidance=$(query_expert_system "$query" "" 5)
        
        if [ $? -eq 0 ] && [ -n "$guidance" ]; then
            echo "Expert Recommendations:"
            echo "======================="
            echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 5
        fi
    fi
}

generate_implementation_plan() {
    local feature_description="$1"
    local technology_stack="$2"
    
    info "Generating expert-guided implementation plan..."
    
    # Cache directory setup
    mkdir -p "$IMPLEMENTATION_CACHE_DIR"
    local cache_file="$IMPLEMENTATION_CACHE_DIR/impl-plan-$(date +%Y%m%d-%H%M%S).json"
    
    # Get comprehensive guidance
    local code_guidance
    code_guidance=$(get_code_implementation_guidance "$feature_description" "$technology_stack")
    
    local security_guidance
    security_guidance=$(get_security_guidance "$feature_description" "$technology_stack")
    
    local performance_guidance
    performance_guidance=$(get_performance_guidance "$feature_description" "$technology_stack")
    
    # Generate comprehensive implementation plan
    echo "=========================================="
    echo "EXPERT-GUIDED IMPLEMENTATION PLAN"
    echo "=========================================="
    echo ""
    echo "Feature: $feature_description"
    echo "Technology Stack: $technology_stack"
    echo "Generated: $(date)"
    echo ""
    echo "🔧 IMPLEMENTATION GUIDANCE"
    echo "========================="
    echo "$code_guidance"
    echo ""
    echo "🔒 SECURITY CONSIDERATIONS"
    echo "=========================="
    echo "$security_guidance"
    echo ""
    echo "⚡ PERFORMANCE OPTIMIZATION"
    echo "=========================="
    echo "$performance_guidance"
    echo ""
    echo "📝 IMPLEMENTATION CHECKLIST"
    echo "==========================="
    echo "□ Set up development environment"
    echo "□ Create project structure"
    echo "□ Implement core functionality"
    echo "□ Add error handling"
    echo "□ Implement security measures"
    echo "□ Add logging and monitoring"
    echo "□ Optimize performance"
    echo "□ Write unit tests"
    echo "□ Write integration tests"
    echo "□ Document the implementation"
    echo "□ Review code quality"
    echo "□ Prepare for deployment"
    echo ""
    echo "Implementation plan cached to: $cache_file"
    
    # Save to cache
    cat > "$cache_file" <<EOF
{
    "feature_description": "$feature_description",
    "technology_stack": "$technology_stack",
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "implementation_guidance": $(echo "$code_guidance" | jq -R . | jq -s .),
    "security_guidance": $(echo "$security_guidance" | jq -R . | jq -s .),
    "performance_guidance": $(echo "$performance_guidance" | jq -R . | jq -s .)
}
EOF
}

# Code review functionality
expert_code_review() {
    local file_path="$1"
    local review_type="${2:-general}"
    
    if [ ! -f "$file_path" ]; then
        error "File not found: $file_path"
        return 1
    fi
    
    local technology
    technology=$(detect_file_technology "$file_path")
    
    expert "Performing expert-guided code review..."
    
    # Analyze file content for context
    local file_content
    file_content=$(head -n 50 "$file_path" | tr '\n' ' ' | sed 's/"/\\"/g')
    
    local query="code review $review_type $technology best practices checklist quality"
    local review_guidance
    review_guidance=$(query_expert_system "$query" "code-review-expert" 8)
    
    echo "Expert Code Review: $file_path"
    echo "================================"
    echo "Technology: $technology"
    echo "Review Type: $review_type"
    echo ""
    
    if [ $? -eq 0 ] && [ -n "$review_guidance" ]; then
        echo "Expert Review Guidelines:"
        echo "========================"
        echo "$review_guidance" | jq -r '.results[].content' 2>/dev/null | head -n 10
    else
        echo "General Code Review Checklist:"
        echo "=============================="
        echo "□ Code follows language conventions"
        echo "□ Functions have single responsibility"
        echo "□ Error handling is implemented"
        echo "□ Code is properly commented"
        echo "□ No security vulnerabilities"
        echo "□ Performance considerations addressed"
        echo "□ Tests are included"
        echo "□ Documentation is complete"
    fi
    
    # Perform basic file analysis
    echo ""
    analyze_code_file "$file_path"
}

# Main implementation interface
main() {
    case "${1:-help}" in
        "guide")
            local task="${2:-}"
            local tech="${3:-}"
            if [ -z "$task" ] || [ -z "$tech" ]; then
                error "Usage: $0 guide \"task description\" \"technology\""
                exit 1
            fi
            get_code_implementation_guidance "$task" "$tech"
            ;;
        "api")
            local api_type="${2:-REST}"
            local tech="${3:-}"
            get_api_design_guidance "$api_type" "$tech"
            ;;
        "database")
            local operation="${2:-}"
            local db_type="${3:-}"
            if [ -z "$operation" ]; then
                error "Usage: $0 database \"operation\" [database_type]"
                exit 1
            fi
            get_database_guidance "$operation" "$db_type"
            ;;
        "security")
            local context="${2:-}"
            local tech="${3:-}"
            if [ -z "$context" ]; then
                error "Usage: $0 security \"context\" [technology]"
                exit 1
            fi
            get_security_guidance "$context" "$tech"
            ;;
        "performance")
            local context="${2:-}"
            local tech="${3:-}"
            if [ -z "$context" ]; then
                error "Usage: $0 performance \"context\" [technology]"
                exit 1
            fi
            get_performance_guidance "$context" "$tech"
            ;;
        "analyze")
            local file_path="${2:-}"
            if [ -z "$file_path" ]; then
                error "Usage: $0 analyze \"file_path\""
                exit 1
            fi
            analyze_code_file "$file_path"
            ;;
        "plan")
            local feature="${2:-}"
            local tech_stack="${3:-}"
            if [ -z "$feature" ] || [ -z "$tech_stack" ]; then
                error "Usage: $0 plan \"feature description\" \"technology stack\""
                exit 1
            fi
            generate_implementation_plan "$feature" "$tech_stack"
            ;;
        "review")
            local file_path="${2:-}"
            local review_type="${3:-general}"
            if [ -z "$file_path" ]; then
                error "Usage: $0 review \"file_path\" [review_type]"
                exit 1
            fi
            expert_code_review "$file_path" "$review_type"
            ;;
        "detect")
            local file_path="${2:-}"
            if [ -z "$file_path" ]; then
                error "Usage: $0 detect \"file_path\""
                exit 1
            fi
            technology=$(detect_file_technology "$file_path")
            echo "Detected technology: $technology"
            ;;
        "expert-status")
            if check_expert_system; then
                success "Expert Knowledge Base: Available at $EXPERT_SYSTEM_URL"
                curl -s "$EXPERT_SYSTEM_URL/api/v1/index/stats" | jq '.index_stats' 2>/dev/null || echo "Stats unavailable"
            else
                error "Expert Knowledge Base: Unavailable at $EXPERT_SYSTEM_URL"
            fi
            ;;
        "cache")
            if [ -d "$IMPLEMENTATION_CACHE_DIR" ]; then
                echo "Implementation Cache Contents:"
                echo "============================="
                ls -la "$IMPLEMENTATION_CACHE_DIR"
            else
                echo "No implementation cache found"
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Expert-Guided Implementation System"
            echo "==================================="
            echo ""
            echo "Usage: $0 [command] [arguments]"
            echo ""
            echo "Commands:"
            echo "  guide \"task\" \"tech\"                    Get implementation guidance"
            echo "  api \"type\" [tech]                      Get API design guidance"
            echo "  database \"operation\" [db_type]         Get database guidance"
            echo "  security \"context\" [tech]              Get security guidance"
            echo "  performance \"context\" [tech]           Get performance guidance"
            echo "  analyze \"file_path\"                    Analyze code file"
            echo "  plan \"feature\" \"tech_stack\"          Generate implementation plan"
            echo "  review \"file_path\" [type]              Expert code review"
            echo "  detect \"file_path\"                     Detect file technology"
            echo "  expert-status                           Check Expert Knowledge Base status"
            echo "  cache                                   Show implementation cache"
            echo "  help                                    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 guide \"authentication system\" \"go\"         # Get Go auth guidance"
            echo "  $0 api \"REST\" \"javascript\"                    # Get REST API guidance"
            echo "  $0 database \"optimization\" \"postgresql\"       # Get DB optimization tips"
            echo "  $0 security \"web application\" \"javascript\"    # Get web security guidance"
            echo "  $0 plan \"user management\" \"go docker\"         # Generate implementation plan"
            echo "  $0 review \"src/main.go\" \"security\"            # Security code review"
            echo "  $0 analyze \"src/api/users.js\"                   # Analyze JavaScript file"
            echo ""
            echo "Review Types: general, security, performance, style, architecture"
            echo ""
            echo "Environment Variables:"
            echo "  EXPERT_SYSTEM_URL                Expert Knowledge Base URL (default: http://localhost:8080)"
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