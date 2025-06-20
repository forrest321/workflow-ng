#!/usr/bin/env bash
# Expert-Enhanced Planning System
# Integrates Expert Knowledge Base for intelligent workflow planning

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXPERT_SYSTEM_URL="${EXPERT_SYSTEM_URL:-http://localhost:8080}"
PLANNING_CACHE_DIR="$PROJECT_ROOT/.planning-cache"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[PLANNER]${NC} $*"
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
    local top_k="${3:-10}"
    
    if ! check_expert_system; then
        warn "Expert system unavailable - proceeding with basic planning"
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

# Planning functions
detect_project_technologies() {
    local project_path="${1:-$PROJECT_ROOT}"
    local technologies=()
    
    info "Detecting project technologies in $project_path"
    
    # Check for common technology indicators
    [ -f "$project_path/package.json" ] && technologies+=("javascript" "node.js")
    [ -f "$project_path/go.mod" ] && technologies+=("go" "golang")
    [ -f "$project_path/Cargo.toml" ] && technologies+=("rust")
    [ -f "$project_path/requirements.txt" ] || [ -f "$project_path/pyproject.toml" ] && technologies+=("python")
    [ -f "$project_path/pubspec.yaml" ] && technologies+=("flutter" "dart")
    [ -f "$project_path/pom.xml" ] || [ -f "$project_path/build.gradle" ] && technologies+=("java")
    [ -f "$project_path/Gemfile" ] && technologies+=("ruby" "rails")
    [ -f "$project_path/composer.json" ] && technologies+=("php")
    [ -f "$project_path/Dockerfile" ] && technologies+=("docker")
    [ -f "$project_path/docker-compose.yml" ] && technologies+=("docker-compose")
    [ -f "$project_path/kubernetes.yaml" ] || [ -f "$project_path/k8s" ] && technologies+=("kubernetes")
    [ -d "$project_path/.terraform" ] && technologies+=("terraform")
    [ -f "$project_path/ansible.cfg" ] && technologies+=("ansible")
    
    # Check for framework-specific files
    [ -f "$project_path/next.config.js" ] && technologies+=("nextjs")
    [ -f "$project_path/nuxt.config.js" ] && technologies+=("nuxtjs")
    [ -f "$project_path/svelte.config.js" ] && technologies+=("svelte")
    [ -f "$project_path/vite.config.js" ] && technologies+=("vite")
    [ -f "$project_path/webpack.config.js" ] && technologies+=("webpack")
    
    printf '%s\n' "${technologies[@]}" | sort -u
}

get_architecture_guidance() {
    local project_type="$1"
    local technologies="$2"
    
    info "Consulting Expert Knowledge Base for architecture guidance..."
    
    local query="software architecture best practices design patterns for $project_type using $technologies"
    local guidance
    guidance=$(query_expert_system "$query" "" 8)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        log "Architecture guidance obtained from Expert Knowledge Base"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 10
    else
        warn "No architecture guidance available from Expert Knowledge Base"
        echo "Standard recommendations:"
        echo "- Follow SOLID principles"
        echo "- Implement proper separation of concerns"
        echo "- Use dependency injection"
        echo "- Plan for scalability and maintainability"
    fi
}

get_implementation_strategy() {
    local task_description="$1"
    local technologies="$2"
    
    info "Getting implementation strategy from Expert Knowledge Base..."
    
    local query="implementation strategy development workflow $task_description $technologies best practices"
    local strategy
    strategy=$(query_expert_system "$query" "project-management-expert" 5)
    
    if [ $? -eq 0 ] && [ -n "$strategy" ]; then
        log "Implementation strategy retrieved"
        echo "$strategy" | jq -r '.results[].content' 2>/dev/null | head -n 8
    else
        warn "No specific implementation strategy found"
        echo "General implementation approach:"
        echo "- Break down into manageable tasks"
        echo "- Implement incrementally"
        echo "- Test at each stage"
        echo "- Document as you go"
    fi
}

get_testing_recommendations() {
    local technologies="$1"
    
    info "Querying testing recommendations for detected technologies..."
    
    local query="testing strategy best practices frameworks tools for $technologies"
    local recommendations
    recommendations=$(query_expert_system "$query" "" 6)
    
    if [ $? -eq 0 ] && [ -n "$recommendations" ]; then
        log "Testing recommendations obtained"
        echo "$recommendations" | jq -r '.results[].content' 2>/dev/null | head -n 8
    else
        warn "No specific testing recommendations found"
        echo "General testing recommendations:"
        echo "- Unit tests for core logic"
        echo "- Integration tests for APIs"
        echo "- End-to-end tests for critical paths"
        echo "- Performance testing where applicable"
    fi
}

get_deployment_guidance() {
    local technologies="$1"
    local environment="${2:-production}"
    
    info "Getting deployment guidance for $environment environment..."
    
    local query="deployment best practices $environment $technologies CI/CD pipeline automation"
    local guidance
    guidance=$(query_expert_system "$query" "deployment-expert" 5)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        log "Deployment guidance retrieved"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 8
    else
        warn "No specific deployment guidance found"
        echo "General deployment recommendations:"
        echo "- Use containerization (Docker)"
        echo "- Implement CI/CD pipelines"
        echo "- Plan for rollback strategies"
        echo "- Monitor deployment health"
    fi
}

generate_task_breakdown() {
    local project_description="$1"
    local technologies="$2"
    
    info "Generating expert-guided task breakdown..."
    
    # Cache directory setup
    mkdir -p "$PLANNING_CACHE_DIR"
    local cache_file="$PLANNING_CACHE_DIR/task-breakdown-$(date +%Y%m%d-%H%M%S).json"
    
    # Create comprehensive planning document
    cat > "$cache_file" <<EOF
{
    "project_description": "$project_description",
    "detected_technologies": "$technologies",
    "planning_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "expert_guidance": {
        "architecture": [],
        "implementation": [],
        "testing": [],
        "deployment": []
    },
    "task_breakdown": {
        "planning_phase": [],
        "implementation_phase": [],
        "testing_phase": [],
        "deployment_phase": []
    }
}
EOF
    
    log "Generated planning cache file: $cache_file"
    
    # Add expert guidance to cache
    local arch_guidance
    arch_guidance=$(get_architecture_guidance "$project_description" "$technologies")
    
    local impl_strategy
    impl_strategy=$(get_implementation_strategy "$project_description" "$technologies")
    
    local test_recommendations
    test_recommendations=$(get_testing_recommendations "$technologies")
    
    local deploy_guidance
    deploy_guidance=$(get_deployment_guidance "$technologies")
    
    # Output structured plan
    echo "===========================================" 
    echo "EXPERT-ENHANCED PROJECT PLANNING REPORT"
    echo "==========================================="
    echo ""
    echo "Project: $project_description"
    echo "Technologies: $technologies"
    echo "Generated: $(date)"
    echo ""
    echo "🏗️  ARCHITECTURE GUIDANCE"
    echo "------------------------"
    echo "$arch_guidance"
    echo ""
    echo "⚡ IMPLEMENTATION STRATEGY"
    echo "-------------------------"
    echo "$impl_strategy"
    echo ""
    echo "🧪 TESTING RECOMMENDATIONS"
    echo "--------------------------"
    echo "$test_recommendations"
    echo ""
    echo "🚀 DEPLOYMENT GUIDANCE"
    echo "---------------------"
    echo "$deploy_guidance"
    echo ""
    echo "📋 SUGGESTED TASK PHASES"
    echo "------------------------"
    echo "1. PLANNING PHASE"
    echo "   - Technology stack validation"
    echo "   - Architecture design review"
    echo "   - Resource requirement analysis"
    echo "   - Risk assessment and mitigation"
    echo ""
    echo "2. IMPLEMENTATION PHASE"
    echo "   - Core functionality development"
    echo "   - API design and implementation"
    echo "   - Database schema design"
    echo "   - Frontend/UI development"
    echo ""
    echo "3. TESTING PHASE"
    echo "   - Unit test implementation"
    echo "   - Integration testing"
    echo "   - Performance testing"
    echo "   - Security testing"
    echo ""
    echo "4. DEPLOYMENT PHASE"
    echo "   - Environment preparation"
    echo "   - CI/CD pipeline setup"
    echo "   - Monitoring and logging"
    echo "   - Documentation and handover"
    echo ""
    echo "Planning cache saved to: $cache_file"
}

analyze_project_complexity() {
    local project_path="${1:-$PROJECT_ROOT}"
    
    info "Analyzing project complexity..."
    
    local file_count
    file_count=$(find "$project_path" -type f -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.py" -o -name "*.java" -o -name "*.rs" -o -name "*.dart" | wc -l)
    
    local line_count
    line_count=$(find "$project_path" -type f -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.py" -o -name "*.java" -o -name "*.rs" -o -name "*.dart" -exec cat {} \; | wc -l)
    
    local complexity
    if [ "$file_count" -lt 10 ] && [ "$line_count" -lt 1000 ]; then
        complexity="Simple"
    elif [ "$file_count" -lt 50 ] && [ "$line_count" -lt 10000 ]; then
        complexity="Medium"
    else
        complexity="Complex"
    fi
    
    echo "Project Complexity: $complexity"
    echo "Source Files: $file_count"
    echo "Lines of Code: $line_count"
    
    # Query expert system for complexity-specific guidance
    local query="$complexity project management best practices workflow coordination"
    local complexity_guidance
    complexity_guidance=$(query_expert_system "$query" "project-management-expert" 3)
    
    if [ $? -eq 0 ] && [ -n "$complexity_guidance" ]; then
        echo ""
        echo "Expert Guidance for $complexity Projects:"
        echo "$complexity_guidance" | jq -r '.results[].content' 2>/dev/null | head -n 5
    fi
}

# Main planning interface
main() {
    case "${1:-help}" in
        "detect")
            local project_path="${2:-$PROJECT_ROOT}"
            echo "Detected Technologies:"
            echo "====================="
            detect_project_technologies "$project_path"
            ;;
        "analyze")
            local project_path="${2:-$PROJECT_ROOT}"
            analyze_project_complexity "$project_path"
            ;;
        "plan")
            local description="${2:-}"
            if [ -z "$description" ]; then
                error "Project description required. Usage: $0 plan \"project description\""
                exit 1
            fi
            local techs
            techs=$(detect_project_technologies | tr '\n' ' ')
            generate_task_breakdown "$description" "$techs"
            ;;
        "architecture")
            local project_type="${2:-}"
            local technologies="${3:-}"
            if [ -z "$project_type" ]; then
                error "Project type required. Usage: $0 architecture \"project type\" \"technologies\""
                exit 1
            fi
            get_architecture_guidance "$project_type" "$technologies"
            ;;
        "implementation")
            local task="${2:-}"
            local technologies="${3:-}"
            if [ -z "$task" ]; then
                error "Task description required. Usage: $0 implementation \"task\" \"technologies\""
                exit 1
            fi
            get_implementation_strategy "$task" "$technologies"
            ;;
        "testing")
            local technologies="${2:-}"
            if [ -z "$technologies" ]; then
                techs=$(detect_project_technologies | tr '\n' ' ')
                technologies="$techs"
            fi
            get_testing_recommendations "$technologies"
            ;;
        "deployment")
            local technologies="${2:-}"
            local environment="${3:-production}"
            if [ -z "$technologies" ]; then
                techs=$(detect_project_technologies | tr '\n' ' ')
                technologies="$techs"
            fi
            get_deployment_guidance "$technologies" "$environment"
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
            if [ -d "$PLANNING_CACHE_DIR" ]; then
                echo "Planning Cache Contents:"
                echo "======================="
                ls -la "$PLANNING_CACHE_DIR"
            else
                echo "No planning cache found"
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Expert-Enhanced Planning System"
            echo "==============================="
            echo ""
            echo "Usage: $0 [command] [arguments]"
            echo ""
            echo "Commands:"
            echo "  detect [path]                     Detect project technologies"
            echo "  analyze [path]                    Analyze project complexity"
            echo "  plan \"description\"               Generate comprehensive project plan"
            echo "  architecture \"type\" \"techs\"      Get architecture guidance"
            echo "  implementation \"task\" \"techs\"    Get implementation strategy"
            echo "  testing [technologies]            Get testing recommendations"
            echo "  deployment [technologies] [env]   Get deployment guidance"
            echo "  expert-status                     Check Expert Knowledge Base status"
            echo "  cache                             Show planning cache contents"
            echo "  help                              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 detect                                    # Detect current project technologies"
            echo "  $0 plan \"REST API for e-commerce\"          # Generate comprehensive plan"
            echo "  $0 architecture \"microservice\" \"go docker\" # Get architecture guidance"
            echo "  $0 testing \"javascript react\"              # Get testing recommendations"
            echo "  $0 deployment \"go kubernetes\" staging     # Get staging deployment guidance"
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