# Expert Knowledge Base Quick Reference

## 🧠 85,000+ Expert Knowledge Chunks Available

The workflow framework includes real-time access to specialized expert knowledge across 73 domains.

## 🚀 Quick Commands

### Check Expert System Status
```bash
# Verify Expert Knowledge Base is available
claude-coordinator expert-status

# Get system statistics
curl -s "http://localhost:8080/api/v1/index/stats" | jq .
```

### Planning Phase
```bash
# Detect project technologies
./scripts/expert-enhanced-planner.sh detect

# Generate comprehensive project plan
./scripts/expert-enhanced-planner.sh plan "REST API for e-commerce"

# Get architecture guidance
./scripts/expert-enhanced-planner.sh architecture "microservice" "go docker"
```

### Implementation Phase
```bash
# Get implementation guidance
./scripts/expert-guided-implementation.sh guide "authentication" "go"

# API design recommendations
./scripts/expert-guided-implementation.sh api "REST" "javascript"

# Security guidance
./scripts/expert-guided-implementation.sh security "web app" "node.js"

# Performance optimization
./scripts/expert-guided-implementation.sh performance "database" "postgresql"
```

### Testing & Deployment
```bash
# Generate testing strategy
./scripts/expert-testing-deployment.sh test-plan "API service" "go postgresql"

# Get CI/CD guidance
./scripts/expert-testing-deployment.sh cicd "python flask" github

# Deployment recommendations
./scripts/expert-testing-deployment.sh deploy-plan "web service" "go kubernetes" production
```

### Direct Expert Queries
```bash
# Query specific expert domain
claude-coordinator query-expert "Go error handling best practices" go-expert

# Get coordination guidance
claude-coordinator get-guidance deployment docker

# Technology best practices
claude-coordinator get-practices flutter
```

## 🔧 Redis-Enhanced File Building

### File Operations
```bash
# Test Redis file operations
claude-coordinator test-file-ops

# View active file buffers
claude-coordinator file-buffers

# Clean up stale buffers
claude-coordinator cleanup-buffers
```

### Benefits
- **In-memory file construction** eliminates I/O bottlenecks
- **Atomic operations** with TTL-based locks
- **Incremental building** supports multiple edits
- **Smart fallback** to direct file I/O when Redis unavailable

## 🎯 Expert Domains Available

### Programming Languages (13)
- `javascript-expert`, `go-expert`, `python-expert`, `rust-expert`
- `java-expert`, `ruby-expert`, `php-expert`, `swift-expert`
- `kotlin-expert`, `scala-expert`, `haskell-expert`, `elixir-expert`, `lua-expert`

### Frameworks & Technologies
- `fibrebeam` (Go Fiber), `flutterbeam` (Flutter/Dart)
- `rest-api-expert`, `graphql-expert`, `spring-boot-expert`
- `rails-expert`, `html-expert`, `pwa-expert`

### Infrastructure & DevOps (7)
- `docker-expert`, `kubernetes-expert`, `terraform-expert`
- `ansible-expert`, `linux-expert`, `ubuntu-expert`, `deployment-expert`

### Databases (5)
- `database-expert`, `mysql-expert`, `postgresql-expert`
- `sql-expert`, `firebase-expert`

### Development Tools (9)
- `git-expert`, `github-api-expert`, `cli-expert`
- `security-expert`, `bot-expert`, `code-review-expert`
- `project-management-expert`, `publishing-expert`, `apis`

### Specialized Domains (20+)
- `crypto`, `ethereum-expert`, `monero-expert`, `ipfs-expert`
- `mobile-expert`, `ios-expert`, `electron-expert`, `macos-expert`
- `data-structures-expert`, `nlp-expert`, `jupyter-notebook-expert`
- And many more...

## ⚙️ Configuration

### Environment Variables
```bash
# Expert Knowledge Base URL
export EXPERT_SYSTEM_URL="http://localhost:8080"

# Enable/disable Expert integration
export EXPERT_SYSTEM_ENABLED="true"

# Redis coordination
export REDIS_URL="redis://localhost:6379"
```

### Workflow Configuration
```yaml
# .claude/config/workflow.yml
expert_system:
  enabled: true
  url: "http://localhost:8080"
  auto_consultation: true

redis_file_building:
  enabled: true
  buffer_ttl: 300
```

## 🔄 Integration with Coordination

The Expert system is automatically integrated with:
- **Task Planning**: Expert-guided task breakdown
- **Implementation**: Technology-specific code patterns
- **Testing**: Framework-specific testing strategies
- **Deployment**: Environment-aware deployment guidance
- **Code Review**: AI-powered analysis with security focus

## 🚨 Troubleshooting

### Expert System Unavailable
If Expert system is not available, the workflow gracefully falls back to standard practices:
```bash
# Check if Expert system is running
curl -s "http://localhost:8080/health"

# Start Expert system if needed
cd /Users/fo/Documents/code/experts/vector-knowledge-base
./bin/server &
```

### Redis Issues
```bash
# Check Redis connection
redis-cli ping

# Start Redis if needed
docker-compose -f docker-compose.coordination.yml up -d

# Or start Redis manually
docker run -d -p 6379:6379 redis:7-alpine
```

## 📚 Learn More

- **Expert System Integration Guide**: `.claude/docs/expert-system-integration.md`
- **Full Documentation**: `.claude/README.md`
- **Workflow Rules**: `.claude/rules/workflow-governance.md`

---

**System Status**: 🟢 OPERATIONAL with 85,009 chunks indexed across 73 expert domains
**Performance**: Sub-second semantic search response times
**Integration**: Full workflow lifecycle coverage