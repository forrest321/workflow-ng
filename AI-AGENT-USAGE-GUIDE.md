# AI Agent Usage Guide: Expert Knowledge Base System

## Overview
This document provides instructions for AI agents on how to access and utilize the Expert Knowledge Base system - a comprehensive vector database containing 85,000+ chunks of expert knowledge across 73 domains including programming languages, frameworks, DevOps tools, and specialized technologies.

## ⚠️ IMPORTANT: Connection Protocol
**ALWAYS attempt to connect to the existing server first. DO NOT start a new server unless connection fails.**

### Step 1: Test Server Connection
```bash
# Check if server is running
curl -s "http://localhost:8080/health"

# If successful, you'll see:
# {"status":"healthy","timestamp":"..."}
```

### Step 2: Verify System Status
```bash
# Get current system statistics
curl -s "http://localhost:8080/api/v1/index/stats" | jq .

# Check monitoring dashboard
curl -s "http://localhost:8080/monitoring/dashboard" | jq .
```

### Step 3: Only If Connection Fails
If the above commands return connection errors, then start the server:
```bash
cd /Users/fo/Documents/code/experts/vector-knowledge-base
./bin/server &
```

## Available Expert Domains

### High Priority Domains
- **fibrebeam**: Go Fiber backend development, REST APIs, microservices
- **flutterbeam**: Flutter mobile/desktop development, Dart programming
- **crypto**: Blockchain fundamentals, smart contracts, DeFi, trading, NFTs
- **ethereum-expert**: Ethereum blockchain, Solidity, Web3.js, OpenZeppelin

### Programming Languages (13 domains)
- **python-expert**: Python development, frameworks, libraries
- **javascript-expert**: JavaScript, Node.js, ES6+, modern frameworks
- **go-expert**: Go programming, concurrency, microservices
- **rust-expert**: Rust programming, memory safety, systems programming
- **java-expert**: Java, JVM, enterprise applications, Spring
- **ruby-expert**: Ruby programming, Rails framework
- **php-expert**: PHP development and frameworks
- **swift-expert**: Swift programming for iOS/macOS
- **kotlin-expert**: Kotlin for Android and JVM
- **scala-expert**: Scala programming and functional concepts
- **haskell-expert**: Haskell functional programming
- **elixir-expert**: Elixir and Phoenix framework
- **lua-expert**: Lua scripting and game development

### Infrastructure & DevOps (7 domains)
- **docker-expert**: Docker containers, images, orchestration
- **kubernetes-expert**: Kubernetes orchestration, deployments
- **terraform-expert**: Infrastructure as Code, cloud provisioning
- **ansible-expert**: Configuration management, automation
- **linux-expert**: Linux systems administration
- **ubuntu-expert**: Ubuntu-specific administration
- **deployment-expert**: Application deployment strategies

### Web Development (7 domains)
- **html-expert**: HTML5, semantic markup, accessibility
- **rest-api-expert**: RESTful API design and implementation
- **graphql-expert**: GraphQL APIs and schema design
- **pwa-expert**: Progressive Web Applications
- **rails-expert**: Ruby on Rails framework
- **spring-boot-expert**: Spring Boot Java applications
- **http-expert**: HTTP protocol, headers, status codes

### Database Systems (5 domains)
- **database-expert**: General database design principles
- **mysql-expert**: MySQL database administration
- **postgresql-expert**: PostgreSQL advanced features
- **sql-expert**: SQL queries, optimization, design
- **firebase-expert**: Firebase realtime database, Firestore

### Mobile & Desktop (5 domains)
- **ios-expert**: iOS development, UIKit, SwiftUI
- **mobile-expert**: Cross-platform mobile development
- **electron-expert**: Desktop applications with Electron
- **macos-expert**: macOS development and administration
- **flutter-audio-expert**: Flutter audio/multimedia development

### Blockchain & Cryptocurrency (4 domains)
- **monero-expert**: Monero privacy cryptocurrency
- **ipfs-expert**: InterPlanetary File System
- **crypto**: General blockchain and cryptocurrency
- **ethereum-expert**: Ethereum ecosystem development

### Development Tools (9 domains)
- **git-expert**: Git version control, workflows
- **github-api-expert**: GitHub API integration
- **cli-expert**: Command-line tool development
- **security-expert**: Application security, vulnerabilities
- **bot-expert**: Bot development and automation
- **code-review-expert**: Code review best practices
- **project-management-expert**: Software project management
- **publishing-expert**: Package publishing, distribution
- **apis**: General API design and integration

### Specialized Topics (20+ domains)
- **data-structures-expert**: Algorithms and data structures
- **nlp-expert**: Natural Language Processing
- **json-expert**: JSON processing and APIs
- **jupyter-notebook-expert**: Jupyter notebooks, data science
- **minecraft-expert**: Minecraft modding and development
- **phaser-expert**: Phaser game development framework
- **pico-8-expert**: PICO-8 fantasy console development
- **pixel-art-expert**: Pixel art creation and tools
- **raspberry-pi-expert**: Raspberry Pi projects and IoT
- **sketch-expert**: Sketch design tool usage
- **telegram-expert**: Telegram bot development
- **twitter-expert**: Twitter API integration
- **college-sports-data**: Sports analytics and data
- **music**: Music production and audio processing
- **godot**: Godot game engine development
- **streamdeck-***: 5 StreamDeck-related domains

## API Endpoints

### Search Endpoints
```bash
# Basic semantic search across all domains
curl -X POST "http://localhost:8080/api/v1/search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "how to implement authentication in Go",
    "top_k": 5,
    "filters": {
      "expert": "backend-go-fiber"
    }
  }'

# Enhanced domain-aware search
curl -X POST "http://localhost:8080/api/v1/search/enhanced" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Flutter state management patterns",
    "top_k": 10,
    "domain_weights": {
      "frontend-flutter": 1.0,
      "mobile-expert": 0.7
    }
  }'

# Batch search for multiple queries
curl -X POST "http://localhost:8080/api/v1/search/batch" \
  -H "Content-Type: application/json" \
  -d '{
    "queries": [
      "Docker deployment strategies",
      "Kubernetes scaling patterns"
    ],
    "top_k": 5
  }'
```

### System Information
```bash
# Get indexing statistics
curl -s "http://localhost:8080/api/v1/index/stats"

# System health check
curl -s "http://localhost:8080/health"

# Detailed system status
curl -s "http://localhost:8080/api/v1/system/status"

# Monitoring dashboard
curl -s "http://localhost:8080/monitoring/dashboard"
```

### Management Operations
```bash
# Flush pending operations
curl -X POST "http://localhost:8080/api/v1/system/flush"

# Optimize index performance
curl -X POST "http://localhost:8080/api/v1/index/optimize"

# Rebuild entire index (use with caution)
curl -X POST "http://localhost:8080/api/v1/index/rebuild"
```

## Usage Examples

### Example 1: Finding Go Best Practices
```bash
curl -X POST "http://localhost:8080/api/v1/search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Go error handling best practices",
    "top_k": 5,
    "filters": {
      "technology": "go"
    }
  }' | jq '.results[].content'
```

### Example 2: Flutter Widget Development
```bash
curl -X POST "http://localhost:8080/api/v1/search/enhanced" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "custom Flutter widgets with animations",
    "top_k": 8,
    "domain_weights": {
      "frontend-flutter": 1.0
    },
    "filters": {
      "framework": "flutter"
    }
  }' | jq '.results[] | {score: .score, content: .content[:200]}'
```

### Example 3: DevOps Pipeline Setup
```bash
curl -X POST "http://localhost:8080/api/v1/search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Docker Kubernetes CI/CD pipeline configuration",
    "top_k": 10,
    "filters": {
      "expert": ["docker-expert", "kubernetes-expert"]
    }
  }' | jq '.results[] | {expert: .metadata.expert, content: .content[:150]}'
```

## Best Practices for AI Agents

### 1. Query Optimization
- Use specific, technical queries for better results
- Include technology names, frameworks, or specific concepts
- Combine multiple related terms for comprehensive results

### 2. Domain Filtering
- Use `filters` to narrow results to specific expert domains
- Combine related domains for broader coverage
- Use `domain_weights` in enhanced search for relevance tuning

### 3. Result Processing
- Parse JSON responses to extract relevant content
- Use `jq` for filtering and formatting results
- Check `score` values to assess relevance (higher = more relevant)

### 4. Error Handling
- Always check HTTP status codes
- Implement retry logic for transient failures
- Fall back to broader queries if specific searches return no results

### 5. Performance Considerations
- Use appropriate `top_k` values (5-20 typically sufficient)
- Cache frequently used results when possible
- Monitor system performance via `/monitoring/dashboard`

## System Architecture

### Components
- **Vector Database**: Milvus standalone (Docker)
- **Embeddings**: Ollama with nomic-embed-text (768-dimensional)
- **Caching**: BoltDB for embedding cache
- **Backend**: Go Fiber web framework
- **Monitoring**: Real-time dashboard with metrics

### Current Statistics
- **85,009 chunks** indexed across all domains
- **73 expert domains** fully operational
- **~200,000 source files** processed
- **1,931 cached embeddings** for performance
- **Sub-second search response times**

## Troubleshooting

### Connection Issues
```bash
# Check if Milvus is running
docker ps | grep milvus

# Check server logs
tail -f /var/log/system.log | grep vector-knowledge

# Restart Milvus if needed
cd /Users/fo/Documents/code/experts/vector-knowledge-base
docker-compose restart
```

### Performance Issues
```bash
# Check system resources
curl -s "http://localhost:8080/monitoring/dashboard" | jq '.system_health'

# Monitor indexing progress
watch -n 5 'curl -s "http://localhost:8080/api/v1/index/stats" | jq .index_stats'
```

### Search Quality Issues
- Try broader or more specific queries
- Experiment with different domain filters
- Use enhanced search with domain weights
- Check if the topic is covered in available domains

## Security Notes
- System runs on localhost:8080 (local access only)
- No authentication required for read operations
- Management operations should be used carefully
- Backup system state before rebuild operations

---

**Last Updated**: 2025-06-19 (System fully operational with 85,009 chunks indexed)
**System Status**: 🟢 OPERATIONAL - All 73 expert domains available
**Response Time**: Sub-second semantic search across all domains