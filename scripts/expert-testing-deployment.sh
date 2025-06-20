#!/usr/bin/env bash
# Expert-Enhanced Testing and Deployment System
# Integrates Expert Knowledge Base for intelligent testing and deployment workflows

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXPERT_SYSTEM_URL="${EXPERT_SYSTEM_URL:-http://localhost:8080}"
TEST_DEPLOY_CACHE_DIR="$PROJECT_ROOT/.test-deploy-cache"

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
    echo -e "${GREEN}[TEST-DEPLOY]${NC} $*"
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
        warn "Expert system unavailable - proceeding with standard practices"
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

# Testing guidance functions
get_testing_strategy() {
    local project_type="$1"
    local technology_stack="$2"
    local test_level="${3:-unit}"
    
    expert "Consulting Expert Knowledge Base for testing strategy..."
    
    local query="$test_level testing strategy $project_type $technology_stack frameworks tools best practices"
    local guidance
    guidance=$(query_expert_system "$query" "" 8)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        success "Testing strategy guidance retrieved"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 10
    else
        warn "No specific testing strategy found"
        echo "Standard testing recommendations for $test_level tests:"
        case "$test_level" in
            "unit")
                echo "- Test individual functions/methods"
                echo "- Use mocking for dependencies"
                echo "- Aim for high code coverage"
                echo "- Test edge cases and error conditions"
                ;;
            "integration")
                echo "- Test component interactions"
                echo "- Test API endpoints"
                echo "- Test database operations"
                echo "- Test external service integrations"
                ;;
            "e2e"|"end-to-end")
                echo "- Test complete user workflows"
                echo "- Test critical business paths"
                echo "- Test cross-browser compatibility"
                echo "- Test performance under load"
                ;;
        esac
    fi
}

get_test_automation_guidance() {
    local technology="$1"
    local test_type="${2:-unit}"
    
    expert "Getting test automation guidance..."
    
    local query="$technology $test_type test automation frameworks tools setup configuration"
    local guidance
    guidance=$(query_expert_system "$query" "" 6)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        success "Test automation guidance retrieved"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 8
    else
        warn "No specific test automation guidance found"
        echo "General test automation principles:"
        echo "- Choose appropriate testing framework"
        echo "- Set up continuous integration"
        echo "- Automate test execution"
        echo "- Generate test reports"
        echo "- Maintain test data"
    fi
}

get_deployment_strategy() {
    local environment="$1"
    local technology_stack="$2"
    local deployment_type="${3:-standard}"
    
    expert "Getting deployment strategy from Expert Knowledge Base..."
    
    local query="$deployment_type deployment strategy $environment $technology_stack CI/CD pipeline automation"
    local domain=""
    
    # Select appropriate expert domain
    if [[ "$technology_stack" =~ [Dd]ocker ]]; then
        domain="docker-expert"
    elif [[ "$technology_stack" =~ [Kk]ubernetes ]]; then
        domain="kubernetes-expert"
    elif [[ "$technology_stack" =~ [Tt]erraform ]]; then
        domain="terraform-expert"
    else
        domain="deployment-expert"
    fi
    
    local guidance
    guidance=$(query_expert_system "$query" "$domain" 8)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        success "Deployment strategy guidance retrieved"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 10
    else
        warn "No specific deployment strategy found"
        echo "Standard deployment recommendations for $environment:"
        echo "- Use infrastructure as code"
        echo "- Implement blue-green deployments"
        echo "- Set up monitoring and logging"
        echo "- Plan rollback strategies"
        echo "- Automate health checks"
    fi
}

get_ci_cd_guidance() {
    local technology_stack="$1"
    local platform="${2:-github}"
    
    expert "Getting CI/CD pipeline guidance..."
    
    local query="CI/CD pipeline $platform $technology_stack automation best practices configuration"
    local guidance
    guidance=$(query_expert_system "$query" "" 6)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        success "CI/CD guidance retrieved"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 8
    else
        warn "No specific CI/CD guidance found"
        echo "General CI/CD best practices:"
        echo "- Automate build and test processes"
        echo "- Use environment-specific configurations"
        echo "- Implement security scanning"
        echo "- Set up deployment gates"
        echo "- Monitor pipeline performance"
    fi
}

get_monitoring_guidance() {
    local application_type="$1"
    local technology_stack="$2"
    
    expert "Getting monitoring and observability guidance..."
    
    local query="monitoring observability $application_type $technology_stack logging metrics alerting"
    local guidance
    guidance=$(query_expert_system "$query" "" 6)
    
    if [ $? -eq 0 ] && [ -n "$guidance" ]; then
        success "Monitoring guidance retrieved"
        echo "$guidance" | jq -r '.results[].content' 2>/dev/null | head -n 8
    else
        warn "No specific monitoring guidance found"
        echo "Standard monitoring recommendations:"
        echo "- Implement application logging"
        echo "- Set up health check endpoints"
        echo "- Monitor key performance metrics"
        echo "- Configure alerting rules"
        echo "- Use distributed tracing"
    fi
}

# Project analysis functions
detect_testing_framework() {
    local project_path="${1:-$PROJECT_ROOT}"
    local frameworks=()
    
    info "Detecting testing frameworks in $project_path"
    
    # JavaScript/TypeScript frameworks
    if [ -f "$project_path/package.json" ]; then
        if grep -q "jest" "$project_path/package.json"; then
            frameworks+=("jest")
        fi
        if grep -q "mocha" "$project_path/package.json"; then
            frameworks+=("mocha")
        fi
        if grep -q "cypress" "$project_path/package.json"; then
            frameworks+=("cypress")
        fi
        if grep -q "playwright" "$project_path/package.json"; then
            frameworks+=("playwright")
        fi
    fi
    
    # Go testing
    if find "$project_path" -name "*_test.go" | head -1 >/dev/null 2>&1; then
        frameworks+=("go-test")
    fi
    
    # Python testing
    if [ -f "$project_path/pytest.ini" ] || [ -f "$project_path/pyproject.toml" ]; then
        frameworks+=("pytest")
    fi
    
    # Java testing
    if [ -f "$project_path/pom.xml" ] && grep -q "junit" "$project_path/pom.xml"; then
        frameworks+=("junit")
    fi
    
    printf '%s\n' "${frameworks[@]}" | sort -u
}

detect_deployment_tools() {
    local project_path="${1:-$PROJECT_ROOT}"
    local tools=()
    
    info "Detecting deployment tools in $project_path"
    
    [ -f "$project_path/Dockerfile" ] && tools+=("docker")
    [ -f "$project_path/docker-compose.yml" ] && tools+=("docker-compose")
    [ -d "$project_path/.github/workflows" ] && tools+=("github-actions")
    [ -f "$project_path/.gitlab-ci.yml" ] && tools+=("gitlab-ci")
    [ -f "$project_path/Jenkinsfile" ] && tools+=("jenkins")
    [ -d "$project_path/.terraform" ] && tools+=("terraform")
    [ -f "$project_path/ansible.cfg" ] && tools+=("ansible")
    [ -f "$project_path/helm" ] || [ -d "$project_path/charts" ] && tools+=("helm")
    [ -f "$project_path/skaffold.yaml" ] && tools+=("skaffold")
    
    printf '%s\n' "${tools[@]}" | sort -u
}

# Comprehensive workflow functions
generate_testing_plan() {
    local project_description="$1"
    local technology_stack="$2"
    
    info "Generating expert-guided testing plan..."
    
    mkdir -p "$TEST_DEPLOY_CACHE_DIR"
    local cache_file="$TEST_DEPLOY_CACHE_DIR/testing-plan-$(date +%Y%m%d-%H%M%S).json"
    
    # Detect existing testing setup
    local test_frameworks
    test_frameworks=$(detect_testing_framework | tr '\n' ' ')
    
    # Get expert guidance for different test levels
    local unit_guidance
    unit_guidance=$(get_testing_strategy "$project_description" "$technology_stack" "unit")
    
    local integration_guidance
    integration_guidance=$(get_testing_strategy "$project_description" "$technology_stack" "integration")
    
    local e2e_guidance
    e2e_guidance=$(get_testing_strategy "$project_description" "$technology_stack" "e2e")
    
    local automation_guidance
    automation_guidance=$(get_test_automation_guidance "$technology_stack" "all")
    
    echo "=========================================="
    echo "EXPERT-GUIDED TESTING PLAN"
    echo "=========================================="
    echo ""
    echo "Project: $project_description"
    echo "Technology Stack: $technology_stack"
    echo "Detected Frameworks: $test_frameworks"
    echo "Generated: $(date)"
    echo ""
    echo "🧪 UNIT TESTING STRATEGY"
    echo "========================"
    echo "$unit_guidance"
    echo ""
    echo "🔗 INTEGRATION TESTING STRATEGY"
    echo "==============================="
    echo "$integration_guidance"
    echo ""
    echo "🎯 END-TO-END TESTING STRATEGY"
    echo "=============================="
    echo "$e2e_guidance"
    echo ""
    echo "🤖 TEST AUTOMATION GUIDANCE"
    echo "==========================="
    echo "$automation_guidance"
    echo ""
    echo "📋 TESTING CHECKLIST"
    echo "===================="
    echo "□ Set up testing framework"
    echo "□ Configure test environment"
    echo "□ Write unit tests"
    echo "□ Write integration tests"
    echo "□ Write end-to-end tests"
    echo "□ Set up test data management"
    echo "□ Configure code coverage"
    echo "□ Integrate with CI/CD"
    echo "□ Set up test reporting"
    echo "□ Document testing procedures"
    echo ""
    echo "Testing plan cached to: $cache_file"
    
    # Save to cache
    cat > "$cache_file" <<EOF
{
    "project_description": "$project_description",
    "technology_stack": "$technology_stack",
    "detected_frameworks": "$test_frameworks",
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "unit_guidance": $(echo "$unit_guidance" | jq -R . | jq -s .),
    "integration_guidance": $(echo "$integration_guidance" | jq -R . | jq -s .),
    "e2e_guidance": $(echo "$e2e_guidance" | jq -R . | jq -s .),
    "automation_guidance": $(echo "$automation_guidance" | jq -R . | jq -s .)
}
EOF
}

generate_deployment_plan() {
    local project_description="$1"
    local technology_stack="$2"
    local target_environment="${3:-production}"
    
    info "Generating expert-guided deployment plan..."
    
    mkdir -p "$TEST_DEPLOY_CACHE_DIR"
    local cache_file="$TEST_DEPLOY_CACHE_DIR/deployment-plan-$(date +%Y%m%d-%H%M%S).json"
    
    # Detect existing deployment tools
    local deploy_tools
    deploy_tools=$(detect_deployment_tools | tr '\n' ' ')
    
    # Get expert guidance
    local deployment_strategy
    deployment_strategy=$(get_deployment_strategy "$target_environment" "$technology_stack")
    
    local cicd_guidance
    cicd_guidance=$(get_ci_cd_guidance "$technology_stack")
    
    local monitoring_guidance
    monitoring_guidance=$(get_monitoring_guidance "$project_description" "$technology_stack")
    
    echo "=========================================="
    echo "EXPERT-GUIDED DEPLOYMENT PLAN"
    echo "=========================================="
    echo ""
    echo "Project: $project_description"
    echo "Technology Stack: $technology_stack"
    echo "Target Environment: $target_environment"
    echo "Detected Tools: $deploy_tools"
    echo "Generated: $(date)"
    echo ""
    echo "🚀 DEPLOYMENT STRATEGY"
    echo "======================"
    echo "$deployment_strategy"
    echo ""
    echo "🔄 CI/CD PIPELINE GUIDANCE"
    echo "=========================="
    echo "$cicd_guidance"
    echo ""
    echo "📊 MONITORING & OBSERVABILITY"
    echo "============================="
    echo "$monitoring_guidance"
    echo ""
    echo "📋 DEPLOYMENT CHECKLIST"
    echo "======================="
    echo "□ Set up infrastructure"
    echo "□ Configure environments"
    echo "□ Set up CI/CD pipeline"
    echo "□ Configure secrets management"
    echo "□ Set up monitoring"
    echo "□ Configure logging"
    echo "□ Set up alerting"
    echo "□ Test deployment process"
    echo "□ Plan rollback strategy"
    echo "□ Document deployment procedures"
    echo "□ Set up health checks"
    echo "□ Configure auto-scaling"
    echo ""
    echo "Deployment plan cached to: $cache_file"
    
    # Save to cache
    cat > "$cache_file" <<EOF
{
    "project_description": "$project_description",
    "technology_stack": "$technology_stack",
    "target_environment": "$target_environment",
    "detected_tools": "$deploy_tools",
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "deployment_strategy": $(echo "$deployment_strategy" | jq -R . | jq -s .),
    "cicd_guidance": $(echo "$cicd_guidance" | jq -R . | jq -s .),
    "monitoring_guidance": $(echo "$monitoring_guidance" | jq -R . | jq -s .)
}
EOF
}

# Main interface
main() {
    case "${1:-help}" in
        "test-strategy")
            local project_type="${2:-}"
            local tech_stack="${3:-}"
            local test_level="${4:-unit}"
            if [ -z "$project_type" ] || [ -z "$tech_stack" ]; then
                error "Usage: $0 test-strategy \"project_type\" \"tech_stack\" [test_level]"
                exit 1
            fi
            get_testing_strategy "$project_type" "$tech_stack" "$test_level"
            ;;
        "test-automation")
            local technology="${2:-}"
            local test_type="${3:-unit}"
            if [ -z "$technology" ]; then
                error "Usage: $0 test-automation \"technology\" [test_type]"
                exit 1
            fi
            get_test_automation_guidance "$technology" "$test_type"
            ;;
        "deploy-strategy")
            local environment="${2:-production}"
            local tech_stack="${3:-}"
            local deploy_type="${4:-standard}"
            if [ -z "$tech_stack" ]; then
                error "Usage: $0 deploy-strategy [environment] \"tech_stack\" [deploy_type]"
                exit 1
            fi
            get_deployment_strategy "$environment" "$tech_stack" "$deploy_type"
            ;;
        "cicd")
            local tech_stack="${2:-}"
            local platform="${3:-github}"
            if [ -z "$tech_stack" ]; then
                error "Usage: $0 cicd \"tech_stack\" [platform]"
                exit 1
            fi
            get_ci_cd_guidance "$tech_stack" "$platform"
            ;;
        "monitoring")
            local app_type="${2:-}"
            local tech_stack="${3:-}"
            if [ -z "$app_type" ] || [ -z "$tech_stack" ]; then
                error "Usage: $0 monitoring \"app_type\" \"tech_stack\""
                exit 1
            fi
            get_monitoring_guidance "$app_type" "$tech_stack"
            ;;
        "detect-testing")
            local project_path="${2:-$PROJECT_ROOT}"
            echo "Detected Testing Frameworks:"
            echo "============================"
            detect_testing_framework "$project_path"
            ;;
        "detect-deploy")
            local project_path="${2:-$PROJECT_ROOT}"
            echo "Detected Deployment Tools:"
            echo "=========================="
            detect_deployment_tools "$project_path"
            ;;
        "test-plan")
            local description="${2:-}"
            local tech_stack="${3:-}"
            if [ -z "$description" ] || [ -z "$tech_stack" ]; then
                error "Usage: $0 test-plan \"description\" \"tech_stack\""
                exit 1
            fi
            generate_testing_plan "$description" "$tech_stack"
            ;;
        "deploy-plan")
            local description="${2:-}"
            local tech_stack="${3:-}"
            local environment="${4:-production}"
            if [ -z "$description" ] || [ -z "$tech_stack" ]; then
                error "Usage: $0 deploy-plan \"description\" \"tech_stack\" [environment]"
                exit 1
            fi
            generate_deployment_plan "$description" "$tech_stack" "$environment"
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
            if [ -d "$TEST_DEPLOY_CACHE_DIR" ]; then
                echo "Test & Deploy Cache Contents:"
                echo "============================="
                ls -la "$TEST_DEPLOY_CACHE_DIR"
            else
                echo "No test & deploy cache found"
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Expert-Enhanced Testing and Deployment System"
            echo "============================================="
            echo ""
            echo "Usage: $0 [command] [arguments]"
            echo ""
            echo "Testing Commands:"
            echo "  test-strategy \"type\" \"tech\" [level]     Get testing strategy guidance"
            echo "  test-automation \"tech\" [type]           Get test automation guidance"
            echo "  detect-testing [path]                   Detect testing frameworks"
            echo "  test-plan \"description\" \"tech\"         Generate comprehensive test plan"
            echo ""
            echo "Deployment Commands:"
            echo "  deploy-strategy [env] \"tech\" [type]     Get deployment strategy"
            echo "  cicd \"tech\" [platform]                  Get CI/CD pipeline guidance"
            echo "  monitoring \"app\" \"tech\"                Get monitoring guidance"
            echo "  detect-deploy [path]                    Detect deployment tools"
            echo "  deploy-plan \"desc\" \"tech\" [env]        Generate deployment plan"
            echo ""
            echo "System Commands:"
            echo "  expert-status                           Check Expert Knowledge Base status"
            echo "  cache                                   Show cache contents"
            echo "  help                                    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 test-strategy \"web app\" \"javascript react\" unit"
            echo "  $0 test-automation \"go\" integration"
            echo "  $0 deploy-strategy production \"go docker kubernetes\""
            echo "  $0 cicd \"python flask\" github"
            echo "  $0 monitoring \"microservice\" \"go redis\""
            echo "  $0 test-plan \"REST API\" \"go postgresql\""
            echo "  $0 deploy-plan \"web service\" \"node.js docker\" staging"
            echo ""
            echo "Test Levels: unit, integration, e2e"
            echo "Deploy Types: standard, canary, blue-green, rolling"
            echo "Platforms: github, gitlab, jenkins, azure"
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